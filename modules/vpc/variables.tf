variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cidr_block" {
  description = "VPC CIDR. Default leaves room for many env-scoped /24 subnets."
  type        = string
  default     = "10.0.0.0/16"
}
