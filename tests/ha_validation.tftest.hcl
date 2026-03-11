# tests/ha_validation.tftest.hcl
#
# Unit tests that verify the variable validation rules enforce a minimum of 2
# nodes/subnets for each component, ensuring a highly available topology.
# Each run uses expect_failures to assert that invalid inputs are rejected.

mock_provider "aws" {}
mock_provider "random" {}

# ---------------------------------------------------------------------------
# Shared valid base variables – overridden per-run where needed
# ---------------------------------------------------------------------------

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
# Controller instance count must be >= 2
# ---------------------------------------------------------------------------

run "controller_instance_count_of_1_is_rejected" {
  command = plan

  variables {
    controller_instance_count = 1
  }

  expect_failures = [var.controller_instance_count]
}

# ---------------------------------------------------------------------------
# Hub instance count must be >= 2
# ---------------------------------------------------------------------------

run "hub_instance_count_of_1_is_rejected" {
  command = plan

  variables {
    hub_instance_count = 1
  }

  expect_failures = [var.hub_instance_count]
}

# ---------------------------------------------------------------------------
# Controller subnets must span >= 2 AZs (min list length 2)
# ---------------------------------------------------------------------------

run "single_controller_subnet_is_rejected" {
  command = plan

  variables {
    controller_subnet_ids = ["subnet-0aaaa00001"]
  }

  expect_failures = [var.controller_subnet_ids]
}

# ---------------------------------------------------------------------------
# Hub subnets must span >= 2 AZs (min list length 2)
# ---------------------------------------------------------------------------

run "single_hub_subnet_is_rejected" {
  command = plan

  variables {
    hub_subnet_ids = ["subnet-0bbbb00001"]
  }

  expect_failures = [var.hub_subnet_ids]
}

# ---------------------------------------------------------------------------
# DB subnets must span >= 2 AZs (min list length 2)
# ---------------------------------------------------------------------------

run "single_db_subnet_is_rejected" {
  command = plan

  variables {
    db_subnet_ids = ["subnet-0cccc00001"]
  }

  expect_failures = [var.db_subnet_ids]
}

# ---------------------------------------------------------------------------
# ALB subnets must span >= 2 AZs (min list length 2)
# ---------------------------------------------------------------------------

run "single_alb_subnet_is_rejected" {
  command = plan

  variables {
    alb_subnet_ids = ["subnet-0dddd00001"]
  }

  expect_failures = [var.alb_subnet_ids]
}

# ---------------------------------------------------------------------------
# Positive: exactly 2 of everything is accepted
# ---------------------------------------------------------------------------

run "exactly_two_of_everything_is_accepted" {
  command = plan

  # All variable values come from the top-level defaults which use 2 per list.
  assert {
    condition     = length(aws_instance.controller) == 2
    error_message = "With the minimum valid HA configuration, 2 Controller instances should be planned."
  }

  assert {
    condition     = length(aws_instance.hub) == 2
    error_message = "With the minimum valid HA configuration, 2 Hub instances should be planned."
  }
}

# ---------------------------------------------------------------------------
# Positive: 3 controllers and 3 hubs are also accepted
# ---------------------------------------------------------------------------

run "three_controllers_and_hubs_is_accepted" {
  command = plan

  variables {
    controller_instance_count = 3
    hub_instance_count        = 3
    controller_subnet_ids     = ["subnet-0aaaa00001", "subnet-0aaaa00002", "subnet-0aaaa00003"]
    hub_subnet_ids            = ["subnet-0bbbb00001", "subnet-0bbbb00002", "subnet-0bbbb00003"]
  }

  assert {
    condition     = length(aws_instance.controller) == 3
    error_message = "Expected 3 Controller instances when controller_instance_count = 3."
  }

  assert {
    condition     = length(aws_instance.hub) == 3
    error_message = "Expected 3 Hub instances when hub_instance_count = 3."
  }
}
