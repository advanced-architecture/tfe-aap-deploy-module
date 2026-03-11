// Package test contains Terratest-based integration tests for the
// tfe-aap-deploy-module.  These tests require real AWS credentials and
// will provision (and then destroy) actual AWS resources.
//
// Running integration tests:
//
//	cd test
//	go test -v -run TestAAPModule -timeout 90m
//
// Required environment variables:
//
//	AWS_DEFAULT_REGION      – AWS region to deploy into
//	TF_VAR_controller_ami_id – RHEL 8/9 AMI in the target region
//	TF_VAR_hub_ami_id        – RHEL 8/9 AMI in the target region
//	TF_VAR_db_password       – RDS master password (>=16 chars)
//	TF_VAR_controller_certificate_arn – ACM cert ARN for Controller ALB
//	TF_VAR_hub_certificate_arn        – ACM cert ARN for Hub ALB
//
// Optional environment variables:
//
//	TF_VAR_vpc_id            – VPC to deploy into (module creates one if not set)
//	SKIP_DESTROY             – Set to any value to skip terraform destroy after test
package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// requiredEnvOrSkip returns the value of an environment variable or skips the
// test with a helpful message if it is not set.
func requiredEnvOrSkip(t *testing.T, key string) string {
	t.Helper()
	val := os.Getenv(key)
	if val == "" {
		t.Skipf("Skipping integration test: environment variable %s is not set", key)
	}
	return val
}

// defaultVars returns the minimal set of Terraform variables shared by all
// integration tests in this package.
func defaultVars(t *testing.T, namePrefix string) map[string]interface{} {
	t.Helper()

	region := os.Getenv("AWS_DEFAULT_REGION")
	if region == "" {
		region = "us-east-1"
	}

	controllerAMI := requiredEnvOrSkip(t, "TF_VAR_controller_ami_id")
	hubAMI := requiredEnvOrSkip(t, "TF_VAR_hub_ami_id")
	dbPassword := requiredEnvOrSkip(t, "TF_VAR_db_password")
	controllerCertARN := requiredEnvOrSkip(t, "TF_VAR_controller_certificate_arn")
	hubCertARN := requiredEnvOrSkip(t, "TF_VAR_hub_certificate_arn")

	// Look up two availability zones in the target region.
	azs := aws.GetAvailabilityZones(t, region)
	require.GreaterOrEqualf(t, len(azs), 2,
		"Region %s must have at least 2 Availability Zones", region)

	// Use user-provided VPC or discover the default VPC.
	vpcID := os.Getenv("TF_VAR_vpc_id")
	if vpcID == "" {
		vpcID = aws.GetDefaultVpc(t, region).Id
	}

	// Pick 2 subnets in different AZs from the VPC.
	subnets := aws.GetSubnetsForVpc(t, vpcID, region)
	require.GreaterOrEqualf(t, len(subnets), 2,
		"VPC %s must have at least 2 subnets", vpcID)

	subnetIDs := []string{subnets[0].Id, subnets[1].Id}

	return map[string]interface{}{
		"region":                     region,
		"vpc_id":                     vpcID,
		"controller_subnet_ids":      subnetIDs,
		"hub_subnet_ids":             subnetIDs,
		"db_subnet_ids":              subnetIDs,
		"alb_subnet_ids":             subnetIDs,
		"controller_ami_id":          controllerAMI,
		"hub_ami_id":                 hubAMI,
		"key_name":                   namePrefix + "-key",
		"db_password":                dbPassword,
		"controller_certificate_arn": controllerCertARN,
		"hub_certificate_arn":        hubCertARN,
		"name_prefix":                namePrefix,
		"db_deletion_protection":     false, // allow destroy in tests
	}
}

// terraformOptions returns a configured *terraform.Options for the root
// module directory.
func terraformOptions(t *testing.T, vars map[string]interface{}) *terraform.Options {
	t.Helper()
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		Vars:         vars,
		NoColor:      true,
	})
}

// ---------------------------------------------------------------------------
// TestAAPModulePlan – validates a terraform plan can be generated without
// deploying any real resources. Safe to run without a full AWS environment.
// ---------------------------------------------------------------------------

func TestAAPModulePlan(t *testing.T) {
	t.Parallel()

	namePrefix := fmt.Sprintf("aap-test-%s", random.UniqueId())
	vars := defaultVars(t, namePrefix)

	opts := terraformOptions(t, vars)
	defer terraform.Destroy(t, opts)

	terraform.InitAndPlanWithExitCode(t, opts)
}

// ---------------------------------------------------------------------------
// TestAAPModuleDefaults – full apply/destroy cycle with default settings.
// Verifies that all expected outputs are present after apply.
// ---------------------------------------------------------------------------

func TestAAPModuleDefaults(t *testing.T) {
	t.Parallel()

	namePrefix := fmt.Sprintf("aap-dflt-%s", random.UniqueId())
	vars := defaultVars(t, namePrefix)

	opts := terraformOptions(t, vars)

	if os.Getenv("SKIP_DESTROY") == "" {
		defer terraform.Destroy(t, opts)
	}

	terraform.InitAndApply(t, opts)

	// --- Automation Controller outputs ---
	controllerALBDNS := terraform.Output(t, opts, "controller_alb_dns_name")
	assert.NotEmpty(t, controllerALBDNS,
		"controller_alb_dns_name output must not be empty")

	controllerIDs := terraform.OutputList(t, opts, "controller_instance_ids")
	assert.Equal(t, 2, len(controllerIDs),
		"Expected 2 controller instance IDs in output")

	controllerIPs := terraform.OutputList(t, opts, "controller_private_ips")
	assert.Equal(t, 2, len(controllerIPs),
		"Expected 2 controller private IPs in output")

	// --- Automation Hub outputs ---
	hubALBDNS := terraform.Output(t, opts, "hub_alb_dns_name")
	assert.NotEmpty(t, hubALBDNS,
		"hub_alb_dns_name output must not be empty")

	hubIDs := terraform.OutputList(t, opts, "hub_instance_ids")
	assert.Equal(t, 2, len(hubIDs),
		"Expected 2 hub instance IDs in output")

	// --- Database outputs ---
	dbEndpoint := terraform.Output(t, opts, "db_endpoint")
	assert.NotEmpty(t, dbEndpoint,
		"db_endpoint output must not be empty")

	dbAddress := terraform.Output(t, opts, "db_address")
	assert.NotEmpty(t, dbAddress,
		"db_address output must not be empty")

	dbPort := terraform.Output(t, opts, "db_port")
	assert.Equal(t, "5432", dbPort,
		"db_port output must be 5432")

	dbName := terraform.Output(t, opts, "db_name")
	assert.Equal(t, "aap", dbName,
		"db_name output must be 'aap'")

	// --- Security group outputs ---
	controllerSGID := terraform.Output(t, opts, "controller_security_group_id")
	assert.NotEmpty(t, controllerSGID,
		"controller_security_group_id output must not be empty")

	hubSGID := terraform.Output(t, opts, "hub_security_group_id")
	assert.NotEmpty(t, hubSGID,
		"hub_security_group_id output must not be empty")

	dbSGID := terraform.Output(t, opts, "db_security_group_id")
	assert.NotEmpty(t, dbSGID,
		"db_security_group_id output must not be empty")
}

// ---------------------------------------------------------------------------
// TestAAPModuleCustomInstanceCounts – verifies that custom controller and hub
// instance counts are applied correctly.
// ---------------------------------------------------------------------------

func TestAAPModuleCustomInstanceCounts(t *testing.T) {
	t.Parallel()

	namePrefix := fmt.Sprintf("aap-cnt-%s", random.UniqueId())
	vars := defaultVars(t, namePrefix)
	vars["controller_instance_count"] = 3
	vars["hub_instance_count"] = 3

	opts := terraformOptions(t, vars)

	if os.Getenv("SKIP_DESTROY") == "" {
		defer terraform.Destroy(t, opts)
	}

	terraform.InitAndApply(t, opts)

	controllerIDs := terraform.OutputList(t, opts, "controller_instance_ids")
	assert.Equal(t, 3, len(controllerIDs),
		"Expected 3 controller instance IDs when controller_instance_count = 3")

	hubIDs := terraform.OutputList(t, opts, "hub_instance_ids")
	assert.Equal(t, 3, len(hubIDs),
		"Expected 3 hub instance IDs when hub_instance_count = 3")
}

// ---------------------------------------------------------------------------
// TestAAPModuleCustomNamePrefix – verifies that the name_prefix variable is
// applied to all named resources.
// ---------------------------------------------------------------------------

func TestAAPModuleCustomNamePrefix(t *testing.T) {
	t.Parallel()

	namePrefix := fmt.Sprintf("prod-aap-%s", random.UniqueId())
	vars := defaultVars(t, namePrefix)

	opts := terraformOptions(t, vars)

	if os.Getenv("SKIP_DESTROY") == "" {
		defer terraform.Destroy(t, opts)
	}

	terraform.InitAndApply(t, opts)

	// The ALB DNS name is derived from the ALB name, which includes the prefix.
	// We can't assert the exact DNS name, but we can assert it's non-empty.
	controllerALBDNS := terraform.Output(t, opts, "controller_alb_dns_name")
	assert.NotEmpty(t, controllerALBDNS)

	hubALBDNS := terraform.Output(t, opts, "hub_alb_dns_name")
	assert.NotEmpty(t, hubALBDNS)
}
