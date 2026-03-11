# Changelog

## Main Branch -- Untagged

_Features not on a tagged version are considered to be in a testing phase. No Support/SLA for these._

## Released Versions

### Initial Release - v1.0

* Initial release of the AAP HA Deploy Module
  * Provisions Automation Controller EC2 nodes (minimum 2, multi-AZ) behind an internal Application Load Balancer
  * Provisions Automation Hub EC2 nodes (minimum 2, multi-AZ) behind an internal Application Load Balancer
  * Provisions an external PostgreSQL RDS instance (Multi-AZ, gp3, encrypted) for both Controller and Hub
  * Creates security groups following least-privilege: Controller ALB, Hub ALB, Controller nodes, Hub nodes, and RDS
  * Enforces IMDSv2 on all EC2 instances
  * Enforces EBS encryption on all volumes
  * Configures ALB TLS 1.3 policy and HTTP-to-HTTPS redirect listeners
  * Outputs all connection details required to populate the AAP installer inventory
  * Documents prerequisites, dependencies, reference architecture, and post-deployment installation steps in README
