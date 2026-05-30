terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

# Single VPC carries dev + prod. Isolation via subnet tags + IAM/SG scoping.
# See docs/architecture.md for the decision rationale.

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "member-mitra-shared-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "member-mitra-shared-igw" }
}

# ---------- Public subnets (shared) ----------
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "member-mitra-shared-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "member-mitra-shared-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------- Private subnets, per env ----------
resource "aws_subnet" "private_dev" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 10 + count.index)
  availability_zone = local.azs[count.index]
  tags = {
    Name        = "member-mitra-dev-private-${local.azs[count.index]}"
    Tier        = "private"
    Environment = "dev"
  }
}

resource "aws_subnet" "private_prod" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 20 + count.index)
  availability_zone = local.azs[count.index]
  tags = {
    Name        = "member-mitra-prod-private-${local.azs[count.index]}"
    Tier        = "private"
    Environment = "prod"
  }
}

# ---------- NAT gateways (shared) ----------
# One per AZ. Saves ~$45/mo vs running NAT per env.
resource "aws_eip" "nat" {
  count  = length(local.azs)
  domain = "vpc"
  tags   = { Name = "member-mitra-shared-nat-${local.azs[count.index]}" }
}

resource "aws_nat_gateway" "main" {
  count         = length(local.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "member-mitra-shared-nat-${local.azs[count.index]}" }
  depends_on    = [aws_internet_gateway.main]
}

# ---------- Private route tables ----------
resource "aws_route_table" "private_dev" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = { Name = "member-mitra-dev-private-rt-${local.azs[count.index]}", Environment = "dev" }
}

resource "aws_route_table_association" "private_dev" {
  count          = length(aws_subnet.private_dev)
  subnet_id      = aws_subnet.private_dev[count.index].id
  route_table_id = aws_route_table.private_dev[count.index].id
}

resource "aws_route_table" "private_prod" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = { Name = "member-mitra-prod-private-rt-${local.azs[count.index]}", Environment = "prod" }
}

resource "aws_route_table_association" "private_prod" {
  count          = length(aws_subnet.private_prod)
  subnet_id      = aws_subnet.private_prod[count.index].id
  route_table_id = aws_route_table.private_prod[count.index].id
}

# ---------- VPC endpoints (saves NAT data charges, keeps AWS-bound traffic private) ----------
# Gateway endpoints (free).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_dev[*].id,
    aws_route_table.private_prod[*].id,
  )
  tags = { Name = "member-mitra-shared-s3-endpoint" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_dev[*].id,
    aws_route_table.private_prod[*].id,
  )
  tags = { Name = "member-mitra-shared-ddb-endpoint" }
}
