# tests/custom_config.tftest.hcl
#
# Unit tests that verify the module correctly applies custom configuration
# options: custom name prefix, custom instance counts, custom tags, and
# custom instance types.

mock_provider "aws" {}
mock_provider "random" {}

variables {
  region     = "us-east-1"
  vpc_id     = "vpc-0123456789abcdef0"
  key_name   = "prod-key"
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
# Custom name prefix propagates to all named resources
# ---------------------------------------------------------------------------

run "custom_name_prefix_applied_to_controller_sg" {
  command = plan

  variables {
    name_prefix = "prod-aap"
  }

  assert {
    condition     = aws_security_group.controller.name == "prod-aap-controller-sg"
    error_message = "Expected controller SG name 'prod-aap-controller-sg', got '${aws_security_group.controller.name}'."
  }
}

run "custom_name_prefix_applied_to_hub_sg" {
  command = plan

  variables {
    name_prefix = "prod-aap"
  }

  assert {
    condition     = aws_security_group.hub.name == "prod-aap-hub-sg"
    error_message = "Expected hub SG name 'prod-aap-hub-sg', got '${aws_security_group.hub.name}'."
  }
}

run "custom_name_prefix_applied_to_rds_identifier" {
  command = plan

  variables {
    name_prefix = "prod-aap"
  }

  assert {
    condition     = aws_db_instance.aap.identifier == "prod-aap-postgresql"
    error_message = "Expected RDS identifier 'prod-aap-postgresql', got '${aws_db_instance.aap.identifier}'."
  }
}

run "custom_name_prefix_applied_to_controller_alb" {
  command = plan

  variables {
    name_prefix = "prod-aap"
  }

  assert {
    condition     = aws_lb.controller.name == "prod-aap-controller-alb"
    error_message = "Expected controller ALB name 'prod-aap-controller-alb', got '${aws_lb.controller.name}'."
  }
}

run "custom_name_prefix_applied_to_hub_alb" {
  command = plan

  variables {
    name_prefix = "prod-aap"
  }

  assert {
    condition     = aws_lb.hub.name == "prod-aap-hub-alb"
    error_message = "Expected hub ALB name 'prod-aap-hub-alb', got '${aws_lb.hub.name}'."
  }
}

# ---------------------------------------------------------------------------
# Custom instance counts (more than the minimum 2)
# ---------------------------------------------------------------------------

run "three_controller_instances_planned" {
  command = plan

  variables {
    controller_instance_count = 3
    controller_subnet_ids     = ["subnet-0aaaa00001", "subnet-0aaaa00002", "subnet-0aaaa00003"]
  }

  assert {
    condition     = length(aws_instance.controller) == 3
    error_message = "Expected 3 Controller instances when controller_instance_count = 3."
  }
}

run "four_hub_instances_planned" {
  command = plan

  variables {
    hub_instance_count = 4
    hub_subnet_ids     = ["subnet-0bbbb00001", "subnet-0bbbb00002", "subnet-0bbbb00003", "subnet-0bbbb00004"]
  }

  assert {
    condition     = length(aws_instance.hub) == 4
    error_message = "Expected 4 Hub instances when hub_instance_count = 4."
  }
}

run "target_group_attachments_scale_with_controller_count" {
  command = plan

  variables {
    controller_instance_count = 3
    controller_subnet_ids     = ["subnet-0aaaa00001", "subnet-0aaaa00002", "subnet-0aaaa00003"]
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.controller) == 3
    error_message = "Expected 3 Controller TG attachments when controller_instance_count = 3."
  }
}

# ---------------------------------------------------------------------------
# Custom instance types
# ---------------------------------------------------------------------------

run "custom_controller_instance_type" {
  command = plan

  variables {
    controller_instance_type = "m5.2xlarge"
  }

  assert {
    condition = alltrue([
      for inst in aws_instance.controller : inst.instance_type == "m5.2xlarge"
    ])
    error_message = "All Controller nodes should use the custom instance type 'm5.2xlarge'."
  }
}

run "custom_hub_instance_type" {
  command = plan

  variables {
    hub_instance_type = "m5.4xlarge"
  }

  assert {
    condition = alltrue([
      for inst in aws_instance.hub : inst.instance_type == "m5.4xlarge"
    ])
    error_message = "All Hub nodes should use the custom instance type 'm5.4xlarge'."
  }
}

# ---------------------------------------------------------------------------
# Custom volume sizes
# ---------------------------------------------------------------------------

run "custom_controller_root_volume_size" {
  command = plan

  variables {
    controller_root_volume_size_gb = 200
  }

  assert {
    condition = alltrue([
      for inst in aws_instance.controller : inst.root_block_device[0].volume_size == 200
    ])
    error_message = "Controller root volume should be 200 GiB when controller_root_volume_size_gb = 200."
  }
}

run "custom_hub_content_volume_size" {
  command = plan

  variables {
    hub_content_volume_size_gb = 500
  }

  assert {
    condition = alltrue([
      for inst in aws_instance.hub : inst.ebs_block_device[0].volume_size == 500
    ])
    error_message = "Hub content volume should be 500 GiB when hub_content_volume_size_gb = 500."
  }
}

# ---------------------------------------------------------------------------
# Nodes distributed across subnets in round-robin order
# ---------------------------------------------------------------------------

run "controller_nodes_distributed_across_subnets" {
  command = plan

  variables {
    controller_instance_count = 2
    controller_subnet_ids     = ["subnet-0aaaa00001", "subnet-0aaaa00002"]
  }

  assert {
    condition     = aws_instance.controller[0].subnet_id == "subnet-0aaaa00001"
    error_message = "First Controller node should be placed in the first subnet."
  }

  assert {
    condition     = aws_instance.controller[1].subnet_id == "subnet-0aaaa00002"
    error_message = "Second Controller node should be placed in the second subnet."
  }
}

run "hub_nodes_distributed_across_subnets" {
  command = plan

  variables {
    hub_instance_count = 2
    hub_subnet_ids     = ["subnet-0bbbb00001", "subnet-0bbbb00002"]
  }

  assert {
    condition     = aws_instance.hub[0].subnet_id == "subnet-0bbbb00001"
    error_message = "First Hub node should be placed in the first subnet."
  }

  assert {
    condition     = aws_instance.hub[1].subnet_id == "subnet-0bbbb00002"
    error_message = "Second Hub node should be placed in the second subnet."
  }
}

# ---------------------------------------------------------------------------
# IAM instance profile is conditionally attached
# ---------------------------------------------------------------------------

run "no_iam_profile_when_not_specified" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller : inst.iam_instance_profile == null
    ])
    error_message = "iam_instance_profile should be null on Controller nodes when the variable is empty."
  }
}

run "iam_profile_attached_when_specified" {
  command = plan

  variables {
    iam_instance_profile = "AAPInstanceProfile"
  }

  assert {
    condition = alltrue([
      for inst in aws_instance.controller : inst.iam_instance_profile == "AAPInstanceProfile"
    ])
    error_message = "iam_instance_profile should be set on Controller nodes when the variable is provided."
  }
}
