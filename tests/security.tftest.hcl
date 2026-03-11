# tests/security.tftest.hcl
#
# Unit tests that verify security hardening settings are enforced in the plan:
#   - IMDSv2 is required on every EC2 instance
#   - EBS volumes are encrypted on every EC2 instance
#   - RDS storage encryption is enabled
#   - ALB listeners use a modern TLS policy
#   - HTTP listeners redirect to HTTPS (no plaintext traffic)
#   - RDS final-snapshot is taken on deletion (skip_final_snapshot = false)

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
# IMDSv2 enforcement on all EC2 instances
# ---------------------------------------------------------------------------

run "imdsv2_required_on_all_controller_nodes" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller :
      inst.metadata_options[0].http_tokens == "required"
    ])
    error_message = "IMDSv2 (http_tokens = 'required') must be enforced on all Automation Controller nodes."
  }
}

run "imdsv2_required_on_all_hub_nodes" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.hub :
      inst.metadata_options[0].http_tokens == "required"
    ])
    error_message = "IMDSv2 (http_tokens = 'required') must be enforced on all Automation Hub nodes."
  }
}

run "imdsv2_http_endpoint_enabled_on_controllers" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller :
      inst.metadata_options[0].http_endpoint == "enabled"
    ])
    error_message = "The IMDS HTTP endpoint must be 'enabled' on Controller nodes (required for IMDSv2 to function)."
  }
}

run "imdsv2_hop_limit_1_on_controllers" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller :
      inst.metadata_options[0].http_put_response_hop_limit == 1
    ])
    error_message = "IMDS hop limit must be 1 on Controller nodes to prevent container-escape metadata access."
  }
}

run "imdsv2_hop_limit_1_on_hubs" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.hub :
      inst.metadata_options[0].http_put_response_hop_limit == 1
    ])
    error_message = "IMDS hop limit must be 1 on Hub nodes to prevent container-escape metadata access."
  }
}

# ---------------------------------------------------------------------------
# EBS encryption on all EC2 instances
# ---------------------------------------------------------------------------

run "root_volume_encrypted_on_all_controller_nodes" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller :
      inst.root_block_device[0].encrypted == true
    ])
    error_message = "Root EBS volume must be encrypted on all Automation Controller nodes."
  }
}

run "root_volume_encrypted_on_all_hub_nodes" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.hub :
      inst.root_block_device[0].encrypted == true
    ])
    error_message = "Root EBS volume must be encrypted on all Automation Hub nodes."
  }
}

run "content_volume_encrypted_on_all_hub_nodes" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.hub :
      inst.ebs_block_device[0].encrypted == true
    ])
    error_message = "Content EBS volume (/dev/sdb) must be encrypted on all Automation Hub nodes."
  }
}

run "controller_root_volume_type_gp3" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.controller :
      inst.root_block_device[0].volume_type == "gp3"
    ])
    error_message = "Controller root volumes must use gp3 storage."
  }
}

run "hub_root_volume_type_gp3" {
  command = plan

  assert {
    condition = alltrue([
      for inst in aws_instance.hub :
      inst.root_block_device[0].volume_type == "gp3"
    ])
    error_message = "Hub root volumes must use gp3 storage."
  }
}

# ---------------------------------------------------------------------------
# RDS encryption
# ---------------------------------------------------------------------------

run "rds_storage_encrypted" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.storage_encrypted == true
    error_message = "RDS storage must be encrypted at rest."
  }
}

run "rds_final_snapshot_not_skipped" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.skip_final_snapshot == false
    error_message = "skip_final_snapshot must be false to ensure a final snapshot is taken before deletion."
  }
}

# ---------------------------------------------------------------------------
# ALB TLS policy – must use 2023 policy (TLS 1.2+ with TLS 1.3 support)
# ---------------------------------------------------------------------------

run "controller_alb_uses_modern_tls_policy" {
  command = plan

  assert {
    condition     = aws_lb_listener.controller_https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2023-10"
    error_message = "Controller ALB HTTPS listener must use 'ELBSecurityPolicy-TLS13-1-2-2023-10', got '${aws_lb_listener.controller_https.ssl_policy}'."
  }
}

run "hub_alb_uses_modern_tls_policy" {
  command = plan

  assert {
    condition     = aws_lb_listener.hub_https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2023-10"
    error_message = "Hub ALB HTTPS listener must use 'ELBSecurityPolicy-TLS13-1-2-2023-10', got '${aws_lb_listener.hub_https.ssl_policy}'."
  }
}

# ---------------------------------------------------------------------------
# HTTP-to-HTTPS redirect (no plaintext traffic allowed)
# ---------------------------------------------------------------------------

run "controller_http_listener_redirects_to_https" {
  command = plan

  assert {
    condition     = aws_lb_listener.controller_http_redirect.default_action[0].type == "redirect"
    error_message = "Controller HTTP listener must redirect to HTTPS."
  }

  assert {
    condition     = aws_lb_listener.controller_http_redirect.default_action[0].redirect[0].status_code == "HTTP_301"
    error_message = "Controller HTTP-to-HTTPS redirect must use a 301 (permanent) status code."
  }
}

run "hub_http_listener_redirects_to_https" {
  command = plan

  assert {
    condition     = aws_lb_listener.hub_http_redirect.default_action[0].type == "redirect"
    error_message = "Hub HTTP listener must redirect to HTTPS."
  }

  assert {
    condition     = aws_lb_listener.hub_http_redirect.default_action[0].redirect[0].status_code == "HTTP_301"
    error_message = "Hub HTTP-to-HTTPS redirect must use a 301 (permanent) status code."
  }
}

# ---------------------------------------------------------------------------
# ALB listeners use correct ports and protocols
# ---------------------------------------------------------------------------

run "controller_https_listener_on_port_443" {
  command = plan

  assert {
    condition     = aws_lb_listener.controller_https.port == 443
    error_message = "Controller HTTPS listener must be on port 443."
  }
}

run "hub_https_listener_on_port_443" {
  command = plan

  assert {
    condition     = aws_lb_listener.hub_https.port == 443
    error_message = "Hub HTTPS listener must be on port 443."
  }
}

run "controller_http_redirect_listener_on_port_80" {
  command = plan

  assert {
    condition     = aws_lb_listener.controller_http_redirect.port == 80
    error_message = "Controller HTTP redirect listener must be on port 80."
  }
}

run "hub_http_redirect_listener_on_port_80" {
  command = plan

  assert {
    condition     = aws_lb_listener.hub_http_redirect.port == 80
    error_message = "Hub HTTP redirect listener must be on port 80."
  }
}
