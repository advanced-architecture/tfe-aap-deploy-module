terraform {
  required_version = "~> 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(
    {
      "ManagedBy" = "Terraform"
      "Module"    = "tfe-aap-deploy-module"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# --- ALB Security Group: Automation Controller ---
resource "aws_security_group" "controller_alb" {
  name        = "${var.name_prefix}-controller-alb-sg"
  description = "Allow HTTPS ingress to the Automation Controller ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "HTTP from allowed CIDRs (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-controller-alb-sg" })
}

# --- ALB Security Group: Automation Hub ---
resource "aws_security_group" "hub_alb" {
  name        = "${var.name_prefix}-hub-alb-sg"
  description = "Allow HTTPS ingress to the Automation Hub ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "HTTP from allowed CIDRs (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-alb-sg" })
}

# --- Security Group: Automation Controller Nodes ---
resource "aws_security_group" "controller" {
  name        = "${var.name_prefix}-controller-sg"
  description = "Security group for Automation Controller EC2 nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Controller ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.controller_alb.id]
  }

  ingress {
    description = "Receptor mesh port for Controller-to-Controller communication"
    from_port   = 27199
    to_port     = 27199
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "SSH for initial bootstrap (restrict to bastion/management CIDR in production)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.allowed_ingress_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-controller-sg" })
}

# --- Security Group: Automation Hub Nodes ---
resource "aws_security_group" "hub" {
  name        = "${var.name_prefix}-hub-sg"
  description = "Security group for Automation Hub EC2 nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Hub ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.hub_alb.id]
  }

  ingress {
    description     = "HTTPS from Controller nodes (Hub API access)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  ingress {
    description     = "SSH for initial bootstrap (restrict to bastion/management CIDR in production)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.allowed_ingress_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-sg" })
}

# --- Security Group: RDS PostgreSQL ---
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Security group for the AAP external PostgreSQL RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from Controller nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.controller.id]
  }

  ingress {
    description     = "PostgreSQL from Hub nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.hub.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-db-sg" })
}

# ---------------------------------------------------------------------------
# RDS - External PostgreSQL (Multi-AZ)
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "aap" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Subnet group for AAP external PostgreSQL RDS instance"
  subnet_ids  = var.db_subnet_ids

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

resource "aws_db_instance" "aap" {
  identifier        = "${var.name_prefix}-postgresql"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  db_name           = "aap"
  username          = var.db_username
  password          = var.db_password

  allocated_storage     = var.db_allocated_storage_gb
  max_allocated_storage = var.db_max_allocated_storage_gb > 0 ? var.db_max_allocated_storage_gb : null
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.aap.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.name_prefix}-postgresql-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-postgresql" })
}

# ---------------------------------------------------------------------------
# EC2 - Automation Controller Nodes
# ---------------------------------------------------------------------------

resource "aws_instance" "controller" {
  count = var.controller_instance_count

  ami                    = var.controller_ami_id
  instance_type          = var.controller_instance_type
  subnet_id              = var.controller_subnet_ids[count.index % length(var.controller_subnet_ids)]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.controller.id]
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.controller_root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-controller-${count.index + 1}"
      Role = "AutomationController"
    }
  )
}

# ---------------------------------------------------------------------------
# EC2 - Automation Hub Nodes
# ---------------------------------------------------------------------------

resource "aws_instance" "hub" {
  count = var.hub_instance_count

  ami                    = var.hub_ami_id
  instance_type          = var.hub_instance_type
  subnet_id              = var.hub_subnet_ids[count.index % length(var.hub_subnet_ids)]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.hub.id]
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.hub_root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_type           = "gp3"
    volume_size           = var.hub_content_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-hub-${count.index + 1}"
      Role = "AutomationHub"
    }
  )
}

# ---------------------------------------------------------------------------
# Application Load Balancer - Automation Controller
# ---------------------------------------------------------------------------

resource "aws_lb" "controller" {
  name               = "${var.name_prefix}-controller-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.controller_alb.id]
  subnets            = var.alb_subnet_ids

  enable_deletion_protection = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-controller-alb" })
}

resource "aws_lb_target_group" "controller" {
  name        = "${var.name_prefix}-ctrl-tg"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/api/v2/ping/"
    protocol            = "HTTPS"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ctrl-tg" })
}

resource "aws_lb_target_group_attachment" "controller" {
  count            = var.controller_instance_count
  target_group_arn = aws_lb_target_group.controller.arn
  target_id        = aws_instance.controller[count.index].id
  port             = 443
}

resource "aws_lb_listener" "controller_https" {
  load_balancer_arn = aws_lb.controller.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.controller_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controller.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ctrl-https-listener" })
}

resource "aws_lb_listener" "controller_http_redirect" {
  load_balancer_arn = aws_lb.controller.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ctrl-http-redirect" })
}

# ---------------------------------------------------------------------------
# Application Load Balancer - Automation Hub
# ---------------------------------------------------------------------------

resource "aws_lb" "hub" {
  name               = "${var.name_prefix}-hub-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hub_alb.id]
  subnets            = var.alb_subnet_ids

  enable_deletion_protection = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-alb" })
}

resource "aws_lb_target_group" "hub" {
  name        = "${var.name_prefix}-hub-tg"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/api/galaxy/v3/ping/"
    protocol            = "HTTPS"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-tg" })
}

resource "aws_lb_target_group_attachment" "hub" {
  count            = var.hub_instance_count
  target_group_arn = aws_lb_target_group.hub.arn
  target_id        = aws_instance.hub[count.index].id
  port             = 443
}

resource "aws_lb_listener" "hub_https" {
  load_balancer_arn = aws_lb.hub.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.hub_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hub.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-https-listener" })
}

resource "aws_lb_listener" "hub_http_redirect" {
  load_balancer_arn = aws_lb.hub.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-hub-http-redirect" })
}
