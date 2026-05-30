output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.reserved.name
}
