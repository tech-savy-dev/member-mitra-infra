# Bootstrap

One-time setup for the chicken-and-egg resources. Run **manually**, with
admin AWS credentials, **once per AWS account**. Never run from CI.

## What this creates

- **S3 bucket** for Terraform remote state — `member-mitra-tfstate-<suffix>`,
  versioning on, KMS-encrypted, public access blocked.
- **DynamoDB table** for state locking — `member-mitra-tflock`.
- **KMS key** that the SSM Parameter Store SecureStrings will use for
  encryption (and which the state bucket also references for SSE-KMS).
- **GitHub OIDC identity provider** in IAM (one per AWS account).
- **Two IAM roles**, each assumable ONLY via GitHub Actions OIDC:
  - `member-mitra-infra-dev` — assumed by plan + apply workflows when
    the target stack is `shared/` or `environments/dev/`.
  - `member-mitra-infra-prod` — assumed by apply workflow when target
    is `environments/prod/`, gated by GitHub Environment `production`.

## Prerequisites

- AWS account with admin access (locally configured via `aws configure`
  or `aws sso login`).
- `terraform >= 1.7`.
- GitHub organization name and infra-repo name (used in OIDC trust).

## Run

```bash
export GITHUB_ORG=tech-savy-dev
export INFRA_REPO=member-mitra-infra
export AWS_REGION=ap-south-1

terraform init       # local state — by design, this is the seed
terraform apply \
  -var "github_org=${GITHUB_ORG}" \
  -var "infra_repo=${INFRA_REPO}"
```

## Capture outputs

After apply succeeds:

```bash
terraform output -json > bootstrap-outputs.json
```

Then update these files with the real values from the outputs:

| File | Field | From output |
|---|---|---|
| `shared/backend.tf` | `bucket` | `tfstate_bucket_name` |
| `shared/backend.tf` | `dynamodb_table` | `tflock_table_name` |
| `environments/dev/backend.tf` | `bucket` | `tfstate_bucket_name` |
| `environments/dev/backend.tf` | `dynamodb_table` | `tflock_table_name` |
| `environments/prod/backend.tf` | (same) | (same) |
| `.github/workflows/terraform-plan.yml` | role-to-assume (dev) | `oidc_role_dev_arn` |
| `.github/workflows/terraform-apply.yml` | role-to-assume (prod) | `oidc_role_prod_arn` |

## Re-runs

Safe to re-run. All resources are `aws_*` with stable names — Terraform
will no-op if nothing changed. Only re-run if:

- Rotating the KMS key (rare).
- Adding a new GitHub Environment (e.g., `uat`).
- Updating OIDC trust conditions (e.g., adding a new branch).

## Tear-down

Don't. State bucket has 90-day version retention; deleting it loses
recovery for every stack. If you really must, see `docs/runbook.md` →
"Decommission AWS account".
