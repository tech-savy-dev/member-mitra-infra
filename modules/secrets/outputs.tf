output "parameter_arns" {
  description = "ARNs of all SSM parameters, keyed by short name."
  value       = { for k, v in aws_ssm_parameter.secret : k => v.arn }
}

output "parameter_names" {
  value = { for k, v in aws_ssm_parameter.secret : k => v.name }
}
