variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "primary_domain" {
  type    = string
  default = "membermitra.com"
}

variable "alt_domains" {
  description = "Subject alternative names. www aliased to apex by default."
  type        = list(string)
  default     = ["www.membermitra.com"]
}

variable "kms_key_arn" {
  type = string
}

variable "alarm_email" {
  type    = string
  default = ""
}
