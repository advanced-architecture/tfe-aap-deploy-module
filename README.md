# tfe-aap-deploy-module

A Terraform module for deploying a **highly available (HA) Red Hat Ansible Automation Platform (AAP) 2.4** environment on AWS, including Automation Controller and Automation Hub, following Red Hat's enterprise reference architecture.

> **Reference**: [Red Hat AAP 2.4 Installation Guide – Platform Installation Scenarios](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html-single/red_hat_ansible_automation_platform_installation_guide/index#assembly-platform-install-scenario)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Dependencies](#dependencies)
- [Module Resources](#module-resources)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Post-Deployment: AAP Installer Inventory](#post-deployment-aap-installer-inventory)
- [Security Considerations](#security-considerations)

---

## Architecture Overview

This module provisions the AWS infrastructure required to run a **production-grade, highly available AAP 2.4** deployment with the following topology:

```
                        ┌────────────────────────────────────────────────────┐
                        │                      AWS VPC                       │
                        │                                                    │
  Users / CI/CD ───────►│  ┌───────────────────┐   ┌────────────────────┐  │
                        │  │ Controller ALB     │   │  Hub ALB           │  │
                        │  │ (internal, HTTPS)  │   │  (internal, HTTPS) │  │
                        │  └────────┬──────────┘   └─────────┬──────────┘  │
                        │           │                         │              │
                        │  ┌────────┴──────────┐   ┌─────────┴──────────┐  │
                        │  │ Automation         │   │ Automation         │  │
                        │  │ Controller Node 1  │   │ Hub Node 1         │  │
                        │  │ (AZ-1, RHEL 8/9)   │   │ (AZ-1, RHEL 8/9)  │  │
                        │  ├────────────────────┤   ├────────────────────┤  │
                        │  │ Automation         │   │ Automation         │  │
                        │  │ Controller Node 2  │   │ Hub Node 2         │  │
                        │  │ (AZ-2, RHEL 8/9)   │   │ (AZ-2, RHEL 8/9)  │  │
                        │  └────────────────────┘   └────────────────────┘  │
                        │           │                         │              │
                        │           └──────────┬──────────────┘              │
                        │                      │                             │
                        │           ┌──────────┴──────────┐                 │
                        │           │  RDS PostgreSQL      │                 │
                        │           │  Multi-AZ (gp3,      │                 │
                        │           │  encrypted)          │                 │
                        │           └─────────────────────┘                 │
                        └────────────────────────────────────────────────────┘
```

### Components

| Component | Count (default) | Purpose |
|-----------|-----------------|---------|
| Automation Controller | 2 (min) | Orchestrates automation jobs; exposes the AAP UI and REST API |
| Automation Hub | 2 (min) | Private content repository for certified collections and execution environments |
| RDS PostgreSQL (Multi-AZ) | 1 (active + standby) | External shared database required for HA; automatic failover |
| Application Load Balancer | 2 | One per component; distributes traffic across nodes |

> **Note**: Red Hat's reference architecture also supports adding **Execution Nodes** (Hop Nodes) for remote execution. Those are outside the scope of this module's initial release but can be added as separate EC2 instances pointing to the Controller cluster.

---

## Prerequisites

### AWS Account

- An existing **VPC** with at least **2 Availability Zones**.
- **Private subnets** in ≥2 AZs for Controller nodes, Hub nodes, and RDS.
- **Public or private subnets** in ≥2 AZs for the Application Load Balancers (internal ALBs are recommended for enterprise deployments).
- **NAT Gateway** (or equivalent) to allow outbound access from private subnets for Red Hat CDN, package updates, and container registry access.
- An **EC2 SSH Key Pair** for initial node bootstrapping.
- **ACM certificates** for the Controller and Hub ALB HTTPS listeners (DNS validation recommended).

### RHEL Images (AMIs)

- Use a **RHEL 8.6+** or **RHEL 9.x** AWS AMI (available from the AWS Marketplace or from your organization's golden AMI pipeline).
- The AMIs must have access to Red Hat Subscription Manager (RHSM) or be pre-subscribed via **Red Hat Cloud Access**.
- Required RHSM repositories:
  - `rhel-8-for-x86_64-baseos-rpms` (or equivalent RHEL 9 repos)
  - `rhel-8-for-x86_64-appstream-rpms`
  - `ansible-automation-platform-2.4-for-rhel-8-x86_64-rpms`

### Red Hat Subscriptions

- Active **Red Hat Ansible Automation Platform** subscription with valid manifest or offline token.
- Download the **AAP 2.4 installer bundle** (`ansible-automation-platform-setup-bundle-2.4.x-x.tar.gz`) from the [Red Hat Customer Portal](https://access.redhat.com/downloads/content/480).

### Terraform / HCP Terraform

- Terraform CLI **~> 1.7** or HCP Terraform workspace.
- AWS provider **~> 5.0**.
- Credentials with permissions to manage EC2, RDS, ALB, Security Groups, and IAM instance profiles.

---

## Dependencies

| Dependency | Version | Notes |
|------------|---------|-------|
| Terraform | ~> 1.7 | Required |
| AWS Provider (`hashicorp/aws`) | ~> 5.0 | Required |
| RHEL 8.6+ or RHEL 9.x AMI | — | Must be pre-subscribed or use Cloud Access |
| PostgreSQL | 13 or 14 | Provisioned as AWS RDS Multi-AZ |
| AAP Installer | 2.4.x | Run post-Terraform on the nodes |

> This module provisions **infrastructure only**. The AAP software installation must be performed afterwards using the Red Hat-provided `setup.sh` installer script with a populated inventory file. See [Post-Deployment: AAP Installer Inventory](#post-deployment-aap-installer-inventory).

---

## Module Resources

The following AWS resources are created by this module:

| Resource Type | Name Pattern | Purpose |
|---------------|-------------|---------|
| `aws_security_group` | `<prefix>-controller-alb-sg` | Controller ALB ingress rules |
| `aws_security_group` | `<prefix>-hub-alb-sg` | Hub ALB ingress rules |
| `aws_security_group` | `<prefix>-controller-sg` | Controller node ingress/egress rules |
| `aws_security_group` | `<prefix>-hub-sg` | Hub node ingress/egress rules |
| `aws_security_group` | `<prefix>-db-sg` | RDS ingress from Controller and Hub |
| `aws_db_subnet_group` | `<prefix>-db-subnet-group` | RDS subnet group spanning ≥2 AZs |
| `aws_db_instance` | `<prefix>-postgresql` | Multi-AZ PostgreSQL 14, gp3, encrypted |
| `aws_instance` (×N) | `<prefix>-controller-<n>` | Automation Controller EC2 nodes |
| `aws_instance` (×N) | `<prefix>-hub-<n>` | Automation Hub EC2 nodes |
| `aws_lb` | `<prefix>-controller-alb` | Internal ALB for Controller |
| `aws_lb_target_group` | `<prefix>-ctrl-tg` | Target group for Controller nodes |
| `aws_lb_listener` (×2) | `<prefix>-ctrl-*` | HTTPS (443) + HTTP→HTTPS redirect |
| `aws_lb_target_group_attachment` | — | Attaches Controller instances to TG |
| `aws_lb` | `<prefix>-hub-alb` | Internal ALB for Hub |
| `aws_lb_target_group` | `<prefix>-hub-tg` | Target group for Hub nodes |
| `aws_lb_listener` (×2) | `<prefix>-hub-*` | HTTPS (443) + HTTP→HTTPS redirect |
| `aws_lb_target_group_attachment` | — | Attaches Hub instances to TG |

---

## Usage

```hcl
module "aap" {
  source = "app.terraform.io/<ORG>/aap-deploy/aws"
  version = "~> 1.0"

  region = "us-east-1"

  # Networking
  vpc_id                = "vpc-0abc123456789"
  controller_subnet_ids = ["subnet-0aaa111", "subnet-0bbb222"]
  hub_subnet_ids        = ["subnet-0ccc333", "subnet-0ddd444"]
  db_subnet_ids         = ["subnet-0eee555", "subnet-0fff666"]
  alb_subnet_ids        = ["subnet-0ggg777", "subnet-0hhh888"]
  allowed_ingress_cidrs = ["10.0.0.0/8"]

  # EC2
  controller_ami_id = "ami-0abcdef1234567890"  # RHEL 8 or 9
  hub_ami_id        = "ami-0abcdef1234567891"  # RHEL 8 or 9
  key_name          = "my-ssh-key"

  # Database
  db_password = var.aap_db_password  # Use a sensitive variable or Vault

  # TLS
  controller_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/aaaa-bbbb"
  hub_certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/cccc-dddd"

  name_prefix = "prod-aap"
  tags = {
    Environment = "production"
    Team        = "platform-engineering"
  }
}

output "controller_url" {
  value = "https://${module.aap.controller_alb_dns_name}"
}

output "hub_url" {
  value = "https://${module.aap.hub_alb_dns_name}"
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `region` | AWS region for all resources | `string` | — | yes |
| `vpc_id` | ID of an existing VPC | `string` | — | yes |
| `controller_subnet_ids` | Private subnet IDs (≥2 AZs) for Controller nodes | `list(string)` | — | yes |
| `hub_subnet_ids` | Private subnet IDs (≥2 AZs) for Hub nodes | `list(string)` | — | yes |
| `db_subnet_ids` | Private subnet IDs (≥2 AZs) for RDS | `list(string)` | — | yes |
| `alb_subnet_ids` | Subnet IDs (≥2 AZs) for ALBs | `list(string)` | — | yes |
| `allowed_ingress_cidrs` | CIDRs allowed to reach ALBs on port 443 | `list(string)` | `["10.0.0.0/8"]` | no |
| `controller_instance_count` | Number of Controller nodes (min 2) | `number` | `2` | no |
| `controller_instance_type` | EC2 instance type for Controller nodes | `string` | `"m5.xlarge"` | no |
| `controller_ami_id` | RHEL 8/9 AMI ID for Controller nodes | `string` | — | yes |
| `controller_root_volume_size_gb` | Root EBS volume size (GiB) for Controller nodes | `number` | `100` | no |
| `hub_instance_count` | Number of Hub nodes (min 2) | `number` | `2` | no |
| `hub_instance_type` | EC2 instance type for Hub nodes | `string` | `"m5.xlarge"` | no |
| `hub_ami_id` | RHEL 8/9 AMI ID for Hub nodes | `string` | — | yes |
| `hub_root_volume_size_gb` | Root EBS volume size (GiB) for Hub nodes | `number` | `100` | no |
| `hub_content_volume_size_gb` | Content EBS volume size (GiB) for Hub nodes | `number` | `200` | no |
| `key_name` | EC2 SSH key pair name | `string` | — | yes |
| `iam_instance_profile` | IAM instance profile name for EC2 nodes | `string` | `""` | no |
| `db_engine_version` | PostgreSQL engine version (13 or 14 required) | `string` | `"14.12"` | no |
| `db_instance_class` | RDS instance class | `string` | `"db.m5.large"` | no |
| `db_allocated_storage_gb` | Initial RDS storage (GiB) | `number` | `100` | no |
| `db_max_allocated_storage_gb` | Max RDS autoscaled storage (GiB); 0 disables autoscaling | `number` | `500` | no |
| `db_username` | PostgreSQL master username | `string` | `"aap_admin"` | no |
| `db_password` | PostgreSQL master password (min 16 chars, sensitive) | `string` | — | yes |
| `db_backup_retention_days` | RDS backup retention in days (1–35) | `number` | `7` | no |
| `db_deletion_protection` | Enable RDS deletion protection | `bool` | `true` | no |
| `controller_certificate_arn` | ACM certificate ARN for Controller ALB | `string` | — | yes |
| `hub_certificate_arn` | ACM certificate ARN for Hub ALB | `string` | — | yes |
| `name_prefix` | Prefix prepended to all resource names | `string` | `"aap"` | no |
| `tags` | Additional tags applied to all resources | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `controller_alb_dns_name` | DNS name of the Automation Controller ALB |
| `controller_alb_arn` | ARN of the Automation Controller ALB |
| `controller_instance_ids` | EC2 instance IDs of Controller nodes |
| `controller_private_ips` | Private IPs of Controller nodes |
| `hub_alb_dns_name` | DNS name of the Automation Hub ALB |
| `hub_alb_arn` | ARN of the Automation Hub ALB |
| `hub_instance_ids` | EC2 instance IDs of Hub nodes |
| `hub_private_ips` | Private IPs of Hub nodes |
| `db_endpoint` | PostgreSQL RDS connection endpoint (host:port) |
| `db_address` | PostgreSQL RDS hostname |
| `db_port` | PostgreSQL RDS port |
| `db_name` | PostgreSQL default database name |
| `controller_security_group_id` | Security group ID for Controller nodes |
| `hub_security_group_id` | Security group ID for Hub nodes |
| `db_security_group_id` | Security group ID for the RDS instance |

---

## Post-Deployment: AAP Installer Inventory

After Terraform applies successfully, run the **Red Hat AAP 2.4 installer** on one of the Controller nodes using an inventory file similar to the following. Substitute the Terraform output values for hostnames/IPs.

```ini
# Example AAP 2.4 installer inventory for HA with Automation Hub
# See: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html-single/red_hat_ansible_automation_platform_installation_guide/

[automationcontroller]
<controller_private_ip_1> ansible_user=ec2-user ansible_become=true
<controller_private_ip_2> ansible_user=ec2-user ansible_become=true

[automationhub]
<hub_private_ip_1> ansible_user=ec2-user ansible_become=true
<hub_private_ip_2> ansible_user=ec2-user ansible_become=true

[all:vars]
# Admin credentials
admin_password='<strong-admin-password>'

# External PostgreSQL database (from Terraform outputs)
pg_host='<db_address output>'
pg_port=5432
pg_database='aap'
pg_username='aap_admin'
pg_password='<db_password>'
pg_sslmode='verify-full'

# AAP Controller settings
automationcontroller_lb_host='<controller_alb_dns_name output>'

# Automation Hub settings
automationhub_admin_password='<strong-hub-admin-password>'
automationhub_pg_host='<db_address output>'
automationhub_pg_port=5432
automationhub_pg_database='automationhub'
automationhub_pg_username='aap_admin'
automationhub_pg_password='<db_password>'
automationhub_pg_sslmode='verify-full'

# Red Hat subscription
# Use either offline_token or registry_username/password
registry_url='registry.redhat.io'
registry_username='<rh-registry-username>'
registry_password='<rh-registry-password>'
```

Run the installer:

```bash
tar xzf ansible-automation-platform-setup-bundle-2.4.x-x.tar.gz
cd ansible-automation-platform-setup-bundle-2.4.x-x/
./setup.sh -i inventory
```

---

## Security Considerations

- **IMDSv2 is enforced** on all EC2 instances (`http_tokens = "required"`) to prevent SSRF-based metadata attacks.
- **EBS volumes are encrypted at rest** on all EC2 instances and the RDS instance.
- **RDS storage is encrypted** using the default AWS-managed KMS key. For stricter compliance, provide a customer-managed KMS key via the `kms_key_id` argument (not exposed as a variable in v1.0; add it for your use case).
- **RDS deletion protection is enabled** by default. Set `db_deletion_protection = false` only for non-production environments.
- **ALB TLS policy** uses `ELBSecurityPolicy-TLS13-1-2-2021-06`, which enforces TLS 1.2+ and supports TLS 1.3.
- **SSH access** on Controller and Hub nodes is allowed from `allowed_ingress_cidrs`. In production, restrict this to a bastion host CIDR or use **AWS Systems Manager Session Manager** (attach an IAM instance profile with `AmazonSSMManagedInstanceCore`).
- **The `db_password` variable is marked `sensitive`** in Terraform to prevent it from appearing in plan/apply output. Store it in HCP Terraform as a sensitive variable or retrieve it from AWS Secrets Manager.
