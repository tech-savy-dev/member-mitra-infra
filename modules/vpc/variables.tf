variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cidr_block" {
  description = "VPC CIDR. Default leaves room for many env-scoped /24 subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat" {
  description = <<EOT
When true, provision 2 NAT Gateways (one per AZ, HA) so private
subnets can reach the internet. Costs ~$66/mo.

Leave FALSE while there are no private workloads. V1 has none:
frontend is S3+CloudFront (public), backend is Supabase (external).
Flip to true the same PR that adds the first Lambda/ECS/RDS
inside private subnets.
EOT
  type        = bool
  default     = false
}
