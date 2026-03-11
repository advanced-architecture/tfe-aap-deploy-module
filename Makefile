# Makefile for tfe-aap-deploy-module test suite
#
# Targets:
#   make test-unit        Run native Terraform unit tests (no AWS required)
#   make test-integration Run Terratest integration tests (requires AWS)
#   make test-all         Run all tests
#   make lint             Validate Terraform configuration syntax
#   make fmt              Format Terraform files
#   make fmt-check        Check Terraform formatting without modifying files
#   make clean            Remove .terraform directories and lock files

TERRAFORM  ?= terraform
GO         ?= go
GOTEST     ?= $(GO) test
TEST_DIR   := test

# Parallelism for Terratest (-p flag)
TEST_PARALLELISM ?= 5

# Timeout for integration tests (provisioning RDS Multi-AZ takes ~15 min)
INTEGRATION_TIMEOUT ?= 90m

.PHONY: help lint fmt fmt-check test-unit test-integration test-all clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Terraform validation / formatting
# ---------------------------------------------------------------------------

lint: ## Validate Terraform configuration syntax and provider requirements
	$(TERRAFORM) init -backend=false
	$(TERRAFORM) validate

fmt: ## Format all Terraform files in-place
	$(TERRAFORM) fmt -recursive .

fmt-check: ## Check Terraform formatting without modifying files (CI-safe)
	$(TERRAFORM) fmt -recursive -check .

# ---------------------------------------------------------------------------
# Native terraform test (unit / plan-level, no AWS credentials required)
# ---------------------------------------------------------------------------

test-unit: ## Run native Terraform unit tests with mocked providers
	$(TERRAFORM) init -backend=false
	$(TERRAFORM) test

# ---------------------------------------------------------------------------
# Terratest integration tests (requires real AWS credentials)
# ---------------------------------------------------------------------------

test-integration: ## Run Terratest integration tests against real AWS
	@echo "==> Running Terratest integration tests (timeout: $(INTEGRATION_TIMEOUT))"
	@echo "==> Required env vars: AWS_DEFAULT_REGION, TF_VAR_controller_ami_id,"
	@echo "    TF_VAR_hub_ami_id, TF_VAR_db_password, TF_VAR_controller_certificate_arn,"
	@echo "    TF_VAR_hub_certificate_arn"
	cd $(TEST_DIR) && $(GOTEST) -v -timeout $(INTEGRATION_TIMEOUT) -p $(TEST_PARALLELISM) ./...

# ---------------------------------------------------------------------------
# Combined target
# ---------------------------------------------------------------------------

test-all: test-unit test-integration ## Run unit tests then integration tests

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

clean: ## Remove generated .terraform directories and lock files
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	find . -name "terraform.tfstate" -delete 2>/dev/null || true
	find . -name "terraform.tfstate.backup" -delete 2>/dev/null || true
