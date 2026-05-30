# modules/vpc

Single shared VPC for the whole project. Public subnets shared; private
subnets per env (`dev`, `prod`). 2 AZs. NAT gateways are **opt-in** via
`enable_nat` — off by default. VPC endpoints for S3 + DynamoDB
(gateway, free).

## Monthly cost (estimate)

### Default (`enable_nat = false`) — what V1 ships with

| Item | $/mo |
|---|---|
| VPC, IGW, subnets, route tables | $0 |
| Gateway VPC endpoints (S3 + DynamoDB) | $0 |
| **Subtotal** | **$0** |

Private subnets exist but have NO `0.0.0.0/0` route. Anything launched
in them is fully internal (no outbound internet). Correct for our V1
state: no workloads in private subnets.

### When `enable_nat = true`

| Item | $/mo |
|---|---|
| 2 NAT Gateways (one per AZ) | ~$66 |
| 2 Elastic IPs (attached) | $0 |
| **Subtotal** | **~$66** |

Plus per-GB data-processing charges (usage-based). Flip this only when
the first Lambda / ECS task / RDS instance lands in a private subnet.

## When to enable NAT

| Scenario | enable_nat |
|---|---|
| V1 (now) — backend on Supabase, no AWS compute | `false` |
| Adding a Lambda that calls Razorpay API | `true` |
| Migrating Supabase → RDS in private subnet | `true` (RDS itself doesn't need NAT, but ops bastion will) |
| Single-AZ test workload that can tolerate downtime | Consider 1 NAT manually instead of 2 (saves $33) |

Switching `false → true` is a `terraform apply` away. Subnets +
route tables already exist; only the EIPs + NAT GWs + the `0.0.0.0/0`
route get added.

## Reusing

```hcl
module "vpc" {
  source     = "../modules/vpc"
  aws_region = var.aws_region
  cidr_block = "10.0.0.0/16"
  enable_nat = false # default
}
```

Instantiated ONCE in `shared/main.tf`. Read via remote state from env
stacks; don't re-instantiate per env.
