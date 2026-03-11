# tests/db_validation.tftest.hcl
#
# Unit tests that verify the RDS-related variable validation rules are
# enforced:
#   - db_password must be at least 16 characters
#   - db_backup_retention_days must be between 1 and 35

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
# db_password length validation
# ---------------------------------------------------------------------------

run "short_db_password_is_rejected" {
  command = plan

  variables {
    db_password = "tooshort123"
  }

  expect_failures = [var.db_password]
}

run "exactly_15_char_password_is_rejected" {
  command = plan

  variables {
    db_password = "ShortPassword1!"
  }

  expect_failures = [var.db_password]
}

run "exactly_16_char_password_is_accepted" {
  command = plan

  variables {
    db_password = "ValidPassword123"
  }

  assert {
    condition     = aws_db_instance.aap.username == "aap_admin"
    error_message = "A 16-character password should be accepted; RDS instance should be planned."
  }
}

run "long_db_password_is_accepted" {
  command = plan

  variables {
    db_password = "AVeryLongAndSecurePassword!1234567890"
  }

  assert {
    condition     = aws_db_instance.aap.username == "aap_admin"
    error_message = "A long password should be accepted; RDS instance should be planned."
  }
}

# ---------------------------------------------------------------------------
# db_backup_retention_days validation (must be 1–35)
# ---------------------------------------------------------------------------

run "backup_retention_of_zero_is_rejected" {
  command = plan

  variables {
    db_backup_retention_days = 0
  }

  expect_failures = [var.db_backup_retention_days]
}

run "backup_retention_of_36_is_rejected" {
  command = plan

  variables {
    db_backup_retention_days = 36
  }

  expect_failures = [var.db_backup_retention_days]
}

run "backup_retention_of_1_is_accepted" {
  command = plan

  variables {
    db_backup_retention_days = 1
  }

  assert {
    condition     = aws_db_instance.aap.backup_retention_period == 1
    error_message = "db_backup_retention_days = 1 should be accepted."
  }
}

run "backup_retention_of_35_is_accepted" {
  command = plan

  variables {
    db_backup_retention_days = 35
  }

  assert {
    condition     = aws_db_instance.aap.backup_retention_period == 35
    error_message = "db_backup_retention_days = 35 should be accepted."
  }
}

run "default_backup_retention_is_7_days" {
  command = plan

  assert {
    condition     = aws_db_instance.aap.backup_retention_period == 7
    error_message = "Default db_backup_retention_days should be 7."
  }
}

# ---------------------------------------------------------------------------
# RDS deletion protection toggle
# ---------------------------------------------------------------------------

run "deletion_protection_can_be_disabled" {
  command = plan

  variables {
    db_deletion_protection = false
  }

  assert {
    condition     = aws_db_instance.aap.deletion_protection == false
    error_message = "db_deletion_protection = false should produce an RDS plan with deletion_protection disabled."
  }
}

# ---------------------------------------------------------------------------
# RDS storage autoscaling
# ---------------------------------------------------------------------------

run "storage_autoscaling_disabled_when_max_is_zero" {
  command = plan

  variables {
    db_max_allocated_storage_gb = 0
  }

  assert {
    condition     = aws_db_instance.aap.max_allocated_storage == null
    error_message = "max_allocated_storage should be null when db_max_allocated_storage_gb = 0."
  }
}

run "storage_autoscaling_enabled_with_positive_max" {
  command = plan

  variables {
    db_max_allocated_storage_gb = 1000
  }

  assert {
    condition     = aws_db_instance.aap.max_allocated_storage == 1000
    error_message = "max_allocated_storage should be 1000 when db_max_allocated_storage_gb = 1000."
  }
}
