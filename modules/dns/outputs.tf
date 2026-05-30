output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "zone_name" {
  value = aws_route53_zone.main.name
}

output "name_servers" {
  description = "Set these as the domain's nameservers at the registrar."
  value       = aws_route53_zone.main.name_servers
}
