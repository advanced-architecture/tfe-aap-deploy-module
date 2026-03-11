# tests/defaults.tftest.hcl
#
# Unit tests that validate the module produces the correct plan when all
# required variables are provided and optional variables use their defaults.
# Mocked providers are used so no real AWS credentials are required.

mock_provider "aws" {}
mock_provider "random" {}

variables {
  region     = "us-east-1"
  vpc_id     = "vpc-0123456789abcdef0"
  key_name   = "test-key"
  db_password = "SuperSecretPassword1234!!"

  controller_subnet_ids      = ["subnet-0aaaa00001", "subnet-0aaaa00002"]
  hub_subnet_ids             = ["subnet-0bbbb00001", "subnet-0bbbb00002"]
  db_subnet_ids              = ["subnet-0cccc00001", "subnet-0cccc00002"]
  alb_subnet_ids             = ["subnet-0dddd00001", "subnet-0dddd00002"]
  controller_ami_id          = "ami-0abcdef1234567890"
  hub_ami_id                 = "ami-0abcdef1234567891"
  controller_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/aaaa-bbbb-cccc"
  hub_certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/dddd-eeee-ffff"
}

# ---------------------------------------------------------------------------
# EC2 instance counts
# ---------------------------------------------------------------------------

run "default_controller_instance_count" {
  command = plan

  assert {
    condition     = length(aws_instance.controller) == 2
    error_message = "Expected 2 Automation Controller instances with default controller_instance_count, got ${length(aws_instance.controller)}."
  }
}

run "default_hub_instance_count" {
  command = plan

  assert {
    condition     = length(aws_instance.hub) == 2
    error_message = "Expected 2 Automation Hub instances with default hub_instance_count, got ${length(aws_instance.hub)}."
  }
}

# ---------------------------------------------------------------------------
# Default instance types (Red Hat recommended minimum for production)
# ---------------------------------------------------------------------------

run "default_controller_instance_type" {
  command = plan

  assert {
    condition     = aws_instance.controller[0].instance_type == "m5.xlarge"
    error_message = "Expected default controller instance type 'm5.xlarge', got '${aws_instance.controller[0].instance_type}'."
  }
}

run "default_hub_instance_type" {
  command = plan

  assert {
    condition     = aws_instance.hub[0].instance_type == "m5.xlarge"
    error_message = "Expected default hub instance type 'm5.xlarge', got '${aws_instance.hub[0].instance_type}'."
  }
}

# ---------------------------------------------------------------------------
# Default name prefix: "aap"
# ---------------------------------------------------------------------------

run "default_name_prefix_controller_sg" {
  command = plan

  assert {
    condition     = aws_security_group.controller.name == "aap-controller-sg"
    error_message = "Expected controller SG name 'aap-controller-sg', got '${aws_security_group.controller.name}'."
  }
}

run "default_name_prefix_hub_sg" {
  command = plan

  assert {
    condition     = aws_security_group.hub.name == "aap-hub-sg"
    error_message = "Expected hub SG name 'aap-hub-sg', got '${aws_security_group.hub.name}'."
  }
}

run "default_name_prefix_rds" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.identifier == "aap-postgresql"
    error_message = "Expected RDS identifier 'aap-postgresql', got '${aws_db_instance.aap.identifier}'."
  }
}

# ---------------------------------------------------------------------------
# ALB configuration
# ---------------------------------------------------------------------------

run "controller_alb_is_internal" {
  command = plan

  assert {
    condition     = aws_lb.controller.internal == true
    error_message = "Automation Controller ALB must be internal."
  }
}

run "hub_alb_is_internal" {
  command = plan

  assert {
    condition     = aws_lb.hub.internal == true
    error_message = "Automation Hub ALB must be internal."
  }
}

run "controller_alb_is_application_type" {
  command = plan

  assert {
    condition     = aws_lb.controller.load_balancer_type == "application"
    error_message = "Controller ALB must be of type 'application'."
  }
}

run "hub_alb_is_application_type" {
  command = plan

  assert {
    condition     = aws_lb.hub.load_balancer_type == "application"
    error_message = "Hub ALB must be of type 'application'."
  }
}

# ---------------------------------------------------------------------------
# ALB deletion protection
# ---------------------------------------------------------------------------

run "controller_alb_deletion_protection_enabled" {
  command = plan

  assert {
    condition     = aws_lb.controller.enable_deletion_protection == true
    error_message = "Deletion protection must be enabled on the Controller ALB."
  }
}

run "hub_alb_deletion_protection_enabled" {
  command = plan

  assert {
    condition     = aws_lb.hub.enable_deletion_protection == true
    error_message = "Deletion protection must be enabled on the Hub ALB."
  }
}

# ---------------------------------------------------------------------------
# Target group health check paths
# ---------------------------------------------------------------------------

run "controller_target_group_health_check_path" {
  command = plan

  assert {
    condition     = aws_lb_target_group.controller.health_check[0].path == "/api/v2/ping/"
    error_message = "Controller TG health check path must be '/api/v2/ping/'."
  }
}

run "hub_target_group_health_check_path" {
  command = plan

  assert {
    condition     = aws_lb_target_group.hub.health_check[0].path == "/api/galaxy/v3/ping/"
    error_message = "Hub TG health check path must be '/api/galaxy/v3/ping/'."
  }
}

# ---------------------------------------------------------------------------
# RDS defaults
# ---------------------------------------------------------------------------

run "rds_multi_az_enabled" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.multi_az == true
    error_message = "RDS instance must be Multi-AZ for HA."
  }
}

run "rds_engine_is_postgres" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.engine == "postgres"
    error_message = "RDS engine must be 'postgres'."
  }
}

run "rds_default_engine_version" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.engine_version == "14.12"
    error_message = "Default RDS engine version must be '14.12'."
  }
}

run "rds_default_db_name" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.db_name == "aap"
    error_message = "Default RDS database name must be 'aap'."
  }
}

run "rds_deletion_protection_enabled_by_default" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.deletion_protection == true
    error_message = "RDS deletion protection must be enabled by default."
  }
}

run "rds_storage_type_gp3" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.storage_type == "gp3"
    error_message = "RDS storage type must be 'gp3'."
  }
}

# ---------------------------------------------------------------------------
# Target group and listener counts
# ---------------------------------------------------------------------------

run "controller_target_group_attachments_match_instance_count" {
  command = plan

  assert {
    condition     = length(aws_lb_target_group_attachment.controller) == 2
    error_message = "Expected 2 Controller TG attachments matching default instance count."
  }
}

run "hub_target_group_attachments_match_instance_count" {
  command = plan

  assert {
    condition     = length(aws_lb_target_group_attachment.hub) == 2
    error_message = "Expected 2 Hub TG attachments matching default instance count."
  }
}
