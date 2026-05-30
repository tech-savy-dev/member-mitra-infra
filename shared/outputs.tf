output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids_dev" {
  value = module.vpc.private_subnet_ids_dev
}

output "private_subnet_ids_prod" {
  value = module.vpc.private_subnet_ids_prod
}

output "hosted_zone_id" {
  value = module.dns.zone_id
}

output "hosted_zone_name_servers" {
  description = "Set these as the registrar's nameservers."
  value       = module.dns.name_servers
}
