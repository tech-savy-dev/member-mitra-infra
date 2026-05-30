terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

# Minimal observability for V1:
#   - SNS topic for alarm fan-out (email subscribed).
#   - Two basic CloudFront alarms (5xx error rate, surge of 4xx).
#   - One log group reserved for future Lambda/migration use.

resource "aws_sns_topic" "alarms" {
  name = "member-mitra-${var.environment}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudFront metrics are in us-east-1 — caller passes the distribution ID.
resource "aws_cloudwatch_metric_alarm" "cf_5xx_rate" {
  alarm_name          = "member-mitra-${var.environment}-cf-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CloudFront 5xx error rate > 5% for 10 min."
  treat_missing_data  = "notBreaching"
  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_log_group" "reserved" {
  name              = "/member-mitra/${var.environment}/app"
  retention_in_days = 30
}
