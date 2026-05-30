output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids_dev" {
  value = aws_subnet.private_dev[*].id
}

output "private_subnet_ids_prod" {
  value = aws_subnet.private_prod[*].id
}

output "nat_gateway_ids" {
  description = "Empty list when enable_nat=false."
  value       = aws_nat_gateway.main[*].id
}

output "nat_enabled" {
  value = var.enable_nat
}

output "azs" {
  value = local.azs
}
