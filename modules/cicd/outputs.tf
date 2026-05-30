output "github_actions_role_arn" {
  value = data.aws_iam_role.infra.arn
}

output "github_actions_role_name" {
  value = data.aws_iam_role.infra.name
}
