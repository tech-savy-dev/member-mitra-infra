# Architecture

V1 ships frontend on AWS; backend stays on Supabase Cloud.

## Diagram

```
                                  registrar (Namecheap)
                                         │
                                         │ NS records point at Route53
                                         ▼
                          ┌───────────────────────────┐
                          │  Route53 zone             │
                          │  membermitra.com          │
                          │  - apex   → CloudFront-prod
                          │  - www    → CloudFront-prod
                          │  - dev    → CloudFront-dev │
                          └───────────────────────────┘
                                    │              │
                                    ▼              ▼
                          ┌─────────────────┐  ┌─────────────────┐
                          │  CloudFront     │  │  CloudFront     │
                          │  prod distrib   │  │  dev distrib    │
                          │  + WAFv2 (us-1) │  │  + WAFv2 (us-1) │
                          │  + ACM cert     │  │  + ACM cert     │
                          └─────────────────┘  └─────────────────┘
                                    │ OAC              │ OAC
                                    ▼                  ▼
                          ┌─────────────────┐  ┌─────────────────┐
                          │ S3 site-prod    │  │ S3 site-dev     │
                          │ (private)       │  │ (private)       │
                          └─────────────────┘  └─────────────────┘

                          ┌──────────────────────────────────────┐
                          │  VPC  10.0.0.0/16  (ap-south-1)      │
                          │   shared between dev + prod          │
                          │                                       │
                          │   public subnets ─ IGW only          │
                          │   private subnets dev (tag env=dev)  │
                          │   private subnets prod (tag env=prod)│
                          │   NAT: OPT-IN (var.enable_nat=false) │
                          │   VPC endpoints: S3, DynamoDB        │
                          └──────────────────────────────────────┘

  V1 has no private workloads (backend=Supabase, frontend=S3+CloudFront),
  so NAT is intentionally off to save ~$66/mo. Flip enable_nat=true the
  same PR that adds the first Lambda/ECS/RDS inside private subnets.

                          ┌──────────────────────────────────────┐
                          │  SSM Parameter Store (KMS-encrypted) │
                          │   /membermitra/{dev,prod}/...        │
                          │   populated out-of-band              │
                          └──────────────────────────────────────┘

                          ┌──────────────────────────────────────┐
                          │  GitHub Actions OIDC                 │
                          │   member-mitra-infra-dev role        │
                          │   member-mitra-infra-prod role       │
                          │   (no static AWS keys in GitHub)     │
                          └──────────────────────────────────────┘

The app's edge-functions + Postgres + auth remain on:
                          ┌──────────────────────────────────────┐
                          │  Supabase Cloud — Mumbai             │
                          │   project mokhzrbtknnfcurpjylq       │
                          │   (NOT in this Terraform repo)       │
                          └──────────────────────────────────────┘
```

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Backend stays on Supabase Cloud | Avoids 3-4 wk rewrite. AWS only hosts frontend + supporting services. |
| 2 | One shared VPC for dev + prod | Simpler IaC, free at this scale, isolation via subnet tags + IAM scoping. |
| 3 | NAT Gateways OFF by default (`enable_nat = false`) | V1 has zero private workloads (Supabase backend, S3+CloudFront frontend). NAT would burn ~$66/mo for unused capacity. Flip to true when first Lambda/ECS/RDS lands. |
| 4 | VPC endpoints for S3 + DynamoDB | Gateway endpoints are free, save NAT data-processing charges when NAT is later enabled. |
| 5 | CloudFront cert + WAF in us-east-1 | CloudFront requirement; can't change. |
| 6 | OAC, not OAI | OAC is newer, supports SSE-KMS on origin. OAI is legacy. |
| 7 | SSM Parameter Store, not Secrets Manager | Cheaper at our scale; migration to Secrets Manager is trivial later. |
| 8 | Real secret values written out-of-band | Keeps tfvars + state + git clean of plaintext. |
| 9 | OIDC federation, no static AWS keys | GitHub Secrets stays empty of AWS keys. Best 2026 pattern. |
| 10 | Bootstrap = manual + local | Chicken-and-egg for state bucket + OIDC trust. By design. |
| 11 | Apply only via CI on `main` merge | Forces PR review; prevents local drift. |
| 12 | Prod apply gated by GitHub Environment | Required-reviewer gate before prod resources change. |
| 13 | Same-name role pattern, env-scoped trust condition | Easy to grep, easy to audit, easy to extend. |

## Cost summary (steady state, V1 traffic)

| Component | $/mo |
|---|---|
| Bootstrap (S3 + DDB + KMS + IAM) | ~$1 |
| Shared (VPC + endpoints, NAT OFF) | ~$0 |
| DNS (Route53 zone + queries) | ~$1 |
| dev — frontend + WAF + cert + monitoring | ~$8 |
| prod — frontend + WAF + cert + monitoring | ~$10 |
| **Total AWS** | **~$20/mo** |

NAT is opt-in (off in V1). Enabling later adds ~$66/mo per 2-NAT HA
config, or ~$33/mo for single-NAT non-HA.

Plus Supabase + Resend (separate bills). At 1,000 active gyms the AWS
spend stays under $30/mo — the gym backend on Supabase will dominate
the bill (~$85/mo Pro + Small compute).
