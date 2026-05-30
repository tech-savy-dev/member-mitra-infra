# modules/vpc

Single shared VPC for the whole project. Public subnets shared; private
subnets per env (`dev`, `prod`). 2 AZs. 2 NAT gateways (one per AZ,
shared between envs). VPC endpoints for S3 + DynamoDB (gateway, free).

## Monthly cost (estimate)

| Item | $/mo |
|---|---|
| 2 NAT gateways | ~$66 (largest cost) |
| Elastic IPs (idle) | $0 (attached to NAT) |
| Endpoints (S3, DynamoDB gateway) | $0 |
| **Subtotal** | **~$66** |

VPC itself is free. NAT data processing charges are usage-based; pre-
launch traffic is negligible.

## Reusing

```hcl
module "vpc" {
  source     = "../modules/vpc"
  aws_region = var.aws_region
  cidr_block = "10.0.0.0/16"
}
```

Instantiated ONCE in `shared/main.tf`. Read via remote state from env
stacks; don't re-instantiate per env.
