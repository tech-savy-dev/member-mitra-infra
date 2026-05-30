output "s3_bucket_name" {
  value = aws_s3_bucket.site.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.site.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}
