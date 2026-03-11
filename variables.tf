# ---------------------------------------------------------------------------
# General / Networking
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region in which to deploy all resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of an existing VPC in which to deploy AAP resources."
  type        = string
}

variable "controller_subnet_ids" {
  description = "List of private-subnet IDs (across >=2 AZs) for Automation Controller nodes."
  type        = list(string)
  validation {
    condition     = length(var.controller_subnet_ids) >= 2
    error_message = "At least 2 subnets in different Availability Zones are required for a highly available deployment."
  }
}

variable "hub_subnet_ids" {
  description = "List of private-subnet IDs (across >=2 AZs) for Automation Hub nodes."
  type        = list(string)
  validation {
    condition     = length(var.hub_subnet_ids) >= 2
    error_message = "At least 2 subnets in different Availability Zones are required for a highly available deployment."
  }
}

variable "db_subnet_ids" {
  description = "List of private-subnet IDs (across >=2 AZs) for the RDS subnet group."
  type        = list(string)
  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "At least 2 subnets in different Availability Zones are required for RDS Multi-AZ."
  }
}

variable "alb_subnet_ids" {
  description = "List of public (or private) subnet IDs (across >=2 AZs) for Application Load Balancers."
  type        = list(string)
  validation {
    condition     = length(var.alb_subnet_ids) >= 2
    error_message = "At least 2 subnets in different Availability Zones are required for an Application Load Balancer."
  }
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks permitted to reach the ALBs on port 443."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# ---------------------------------------------------------------------------
# EC2 - Automation Controller
# ---------------------------------------------------------------------------

variable "controller_instance_count" {
  description = "Number of Automation Controller nodes. Minimum 2 for HA."
  type        = number
  default     = 2
  validation {
    condition     = var.controller_instance_count >= 2
    error_message = "A minimum of 2 Automation Controller nodes is required for a highly available deployment."
  }
}

variable "controller_instance_type" {
  description = "EC2 instance type for Automation Controller nodes. Red Hat recommends m5.xlarge or larger for production."
  type        = string
  default     = "m5.xlarge"
}

variable "controller_ami_id" {
  description = "AMI ID of the RHEL 8 or RHEL 9 image to use for Automation Controller nodes."
  type        = string
}

variable "controller_root_volume_size_gb" {
  description = "Root EBS volume size in GiB for each Automation Controller node."
  type        = number
  default     = 100
}

# ---------------------------------------------------------------------------
# EC2 - Automation Hub
# ---------------------------------------------------------------------------

variable "hub_instance_count" {
  description = "Number of Automation Hub nodes. Minimum 2 for HA."
  type        = number
  default     = 2
  validation {
    condition     = var.hub_instance_count >= 2
    error_message = "A minimum of 2 Automation Hub nodes is required for a highly available deployment."
  }
}

variable "hub_instance_type" {
  description = "EC2 instance type for Automation Hub nodes. Red Hat recommends m5.xlarge or larger for production."
  type        = string
  default     = "m5.xlarge"
}

variable "hub_ami_id" {
  description = "AMI ID of the RHEL 8 or RHEL 9 image to use for Automation Hub nodes."
  type        = string
}

variable "hub_root_volume_size_gb" {
  description = "Root EBS volume size in GiB for each Automation Hub node."
  type        = number
  default     = 100
}

variable "hub_content_volume_size_gb" {
  description = "Additional EBS volume size in GiB on each Hub node for storing collection/execution-environment artifacts."
  type        = number
  default     = 200
}

# ---------------------------------------------------------------------------
# EC2 - Shared
# ---------------------------------------------------------------------------

variable "key_name" {
  description = "Name of the EC2 SSH key pair to associate with all AAP nodes (used for initial bootstrap and troubleshooting)."
  type        = string
}

variable "iam_instance_profile" {
  description = "Name of an existing IAM instance profile to attach to all AAP EC2 nodes (e.g., for SSM Session Manager access). Leave empty to skip."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# RDS - External PostgreSQL
# ---------------------------------------------------------------------------

variable "db_engine_version" {
  description = "PostgreSQL engine version. AAP 2.4 requires PostgreSQL 13 or 14."
  type        = string
  default     = "14.12"
}

variable "db_instance_class" {
  description = "RDS instance class for the external PostgreSQL database."
  type        = string
  default     = "db.m5.large"
}

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage in GiB for the RDS instance."
  type        = number
  default     = 100
}

variable "db_max_allocated_storage_gb" {
  description = "Upper limit in GiB for RDS storage autoscaling. Set to 0 to disable autoscaling."
  type        = number
  default     = 500
}

variable "db_username" {
  description = "Master username for the PostgreSQL RDS instance."
  type        = string
  default     = "aap_admin"
}

variable "db_password" {
  description = "Master password for the PostgreSQL RDS instance. Must be at least 16 characters."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "The database password must be at least 16 characters long."
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups (1-35)."
  type        = number
  default     = 7
  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 1 and 35."
  }
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the RDS instance."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# ACM / TLS
# ---------------------------------------------------------------------------

variable "controller_certificate_arn" {
  description = "ARN of an ACM certificate to attach to the Automation Controller ALB listener."
  type        = string
}

variable "hub_certificate_arn" {
  description = "ARN of an ACM certificate to attach to the Automation Hub ALB listener."
  type        = string
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "name_prefix" {
  description = "Short prefix prepended to all resource names (e.g., 'prod-aap')."
  type        = string
  default     = "aap"
}

variable "tags" {
  description = "Map of additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
