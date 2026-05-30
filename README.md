# member-mitra-infra

Terraform monorepo for MemberMitra's AWS infrastructure. Sister to the app
repo [`tech-savy-dev/member-mitra`](https://github.com/tech-savy-dev/member-mitra).

## What this deploys

**Scope:** frontend hosting + DNS + WAF + observability + CI plumbing.

The backend stays on **Supabase Cloud** (Mumbai project
`mokhzrbtknnfcurpjylq`). DB, auth, edge functions, realtime: all there,
not on AWS. This repo only owns the React app's static delivery and the
supporting AWS perimeter.

### Live AWS surface

| Resource | Region | Purpose |
|---|---|---|
| VPC (single, shared) | ap-south-1 | foundation for any future AWS workload |
| Route53 hosted zone (`membermitra.com`) | global | prod apex + `www` + `dev` |
| ACM certs | us-east-1 | required by CloudFront |
| S3 site bucket (per env) | ap-south-1 | built React assets |
| CloudFront distribution (per env) | global | delivery + caching + SPA fallback |
| WAFv2 ACL (per env) | us-east-1 | core managed rules + rate limit |
| SSM Parameter Store (per env) | ap-south-1 | secrets, populated out-of-band |
| CloudWatch dashboards + alarms (per env) | ap-south-1 | minimal observability |
| GitHub OIDC role (per env) | global | CI auth, no static keys |

### Two environments

- **`dev`** → `dev.membermitra.com`
- **`prod`** → `membermitra.com` apex (with `www` aliased to apex)

Both share one VPC + one hosted zone (cost optimization for V1). Real
isolation via subnets + IAM. Documented in [`docs/architecture.md`](docs/architecture.md).

## Prerequisites

```
terraform >= 1.7
awscli   >= 2.15  (configured: aws sso login OR aws configure)
tflint   >= 0.50
checkov  >= 3.0   (optional, security linting)
gh       >= 2.40  (optional, for CI debugging)
```

## Quick start

```bash
# 1. (one-time) Apply bootstrap with admin AWS creds — see bootstrap/README.md
cd bootstrap && terraform init && terraform apply

# 2. Plan the shared layer
cd ../shared && terraform init && terraform plan

# 3. Plan an env
cd ../environments/dev && terraform init && terraform plan
```

Real apply happens via CI — see [`.github/workflows/`](.github/workflows/).

## Layout

```
bootstrap/        one-time, manual, local apply
modules/          reusable building blocks
environments/    per-env composition (dev, prod)
shared/           dev + prod share these (VPC, hosted zone)
.github/workflows/  plan-on-PR + apply-on-merge + frontend-deploy
docs/             architecture, runbook
```

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — agent operating manual
- [`HANDOVER.md`](HANDOVER.md) — current state, next step
- [`docs/architecture.md`](docs/architecture.md) — diagram + decisions
- [`docs/runbook.md`](docs/runbook.md) — common ops (rotate secret, invalidate CF, recover state)
