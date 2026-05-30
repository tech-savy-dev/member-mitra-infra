variable "environment" {
  type = string
}

variable "cloudfront_distribution_id" {
  description = "ID of the env's CloudFront distribution."
  type        = string
}

variable "alarm_email" {
  description = "Email subscribed to the alarm SNS topic. Empty = no subscription."
  type        = string
  default     = ""
}
