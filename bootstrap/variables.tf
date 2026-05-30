variable "aws_region" {
  description = "Primary AWS region. CloudFront/ACM stay in us-east-1 by design."
  type        = string
  default     = "ap-south-1"
}

variable "github_org" {
  description = "GitHub organization that owns the infra repo."
  type        = string
}

variable "infra_repo" {
  description = "Infra repo name (used in OIDC trust)."
  type        = string
  default     = "member-mitra-infra"
}
