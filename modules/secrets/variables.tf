variable "environment" {
  type = string
}

variable "kms_key_arn" {
  description = "KMS key from bootstrap; encrypts the SecureStrings."
  type        = string
}

variable "extra_secrets" {
  description = "Additional secret slot paths (relative). Joined under /membermitra/<env>/."
  type        = list(string)
  default     = []
}
