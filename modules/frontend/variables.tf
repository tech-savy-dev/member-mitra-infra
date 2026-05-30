variable "environment" {
  description = "dev | prod"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "primary_domain" {
  description = "Primary domain served by this distribution (e.g. dev.membermitra.com or membermitra.com)."
  type        = string
}

variable "alt_domains" {
  description = "Additional domains on the cert + distribution (e.g. [www.membermitra.com])."
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route53 zone ID for membermitra.com."
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Per-IP request limit per 5-min window before WAF blocks."
  type        = number
  default     = 2000
}
