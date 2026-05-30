variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "primary_domain" {
  type    = string
  default = "dev.membermitra.com"
}

variable "alt_domains" {
  type    = list(string)
  default = []
}

variable "kms_key_arn" {
  description = "KMS key from bootstrap output (kms_key_arn). Used for SSM SecureStrings."
  type        = string
}

variable "alarm_email" {
  description = "Email subscribed to dev alarms. Empty = no subscription."
  type        = string
  default     = ""
}
