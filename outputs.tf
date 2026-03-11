# ---------------------------------------------------------------------------
# Automation Controller Outputs
# ---------------------------------------------------------------------------

output "controller_alb_dns_name" {
  description = "DNS name of the Automation Controller Application Load Balancer."
  value       = aws_lb.controller.dns_name
}

output "controller_alb_arn" {
  description = "ARN of the Automation Controller Application Load Balancer."
  value       = aws_lb.controller.arn
}

output "controller_instance_ids" {
  description = "List of EC2 instance IDs for the Automation Controller nodes."
  value       = aws_instance.controller[*].id
}

output "controller_private_ips" {
  description = "List of private IP addresses assigned to the Automation Controller nodes."
  value       = aws_instance.controller[*].private_ip
}

# ---------------------------------------------------------------------------
# Automation Hub Outputs
# ---------------------------------------------------------------------------

output "hub_alb_dns_name" {
  description = "DNS name of the Automation Hub Application Load Balancer."
  value       = aws_lb.hub.dns_name
}

output "hub_alb_arn" {
  description = "ARN of the Automation Hub Application Load Balancer."
  value       = aws_lb.hub.arn
}

output "hub_instance_ids" {
  description = "List of EC2 instance IDs for the Automation Hub nodes."
  value       = aws_instance.hub[*].id
}

output "hub_private_ips" {
  description = "List of private IP addresses assigned to the Automation Hub nodes."
  value       = aws_instance.hub[*].private_ip
}

# ---------------------------------------------------------------------------
# Database Outputs
# ---------------------------------------------------------------------------

output "db_endpoint" {
  description = "Connection endpoint (host:port) for the AAP PostgreSQL RDS instance."
  value       = aws_db_instance.aap.endpoint
}

output "db_address" {
  description = "Hostname of the AAP PostgreSQL RDS instance."
  value       = aws_db_instance.aap.address
}

output "db_port" {
  description = "Port of the AAP PostgreSQL RDS instance."
  value       = aws_db_instance.aap.port
}

output "db_name" {
  description = "Name of the default database created in the AAP PostgreSQL RDS instance."
  value       = aws_db_instance.aap.db_name
}

# ---------------------------------------------------------------------------
# Security Group Outputs
# ---------------------------------------------------------------------------

output "controller_security_group_id" {
  description = "ID of the security group attached to Automation Controller nodes."
  value       = aws_security_group.controller.id
}

output "hub_security_group_id" {
  description = "ID of the security group attached to Automation Hub nodes."
  value       = aws_security_group.hub.id
}

output "db_security_group_id" {
  description = "ID of the security group attached to the AAP PostgreSQL RDS instance."
  value       = aws_security_group.db.id
}
