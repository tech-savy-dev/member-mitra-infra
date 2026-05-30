# HANDOVER

## Current Status

**Repo scaffolded.** All Terraform modules, environment compositions,
CI workflows, and documentation are written. Nothing has been applied
to AWS yet — waiting on AWS account credentials.

### What's in the repo

| Path | Status |
|---|---|
| `bootstrap/` | written, NOT applied |
| `modules/vpc` | written |
| `modules/dns` | written |
| `modules/frontend` | written |
| `modules/secrets` | written |
| `modules/monitoring` | written |
| `modules/cicd` | written |
| `shared/` | composes VPC + DNS |
| `environments/dev/` | composes frontend + secrets + monitoring |
| `environments/prod/` | composes frontend + secrets + monitoring (apex domain) |
| `.github/workflows/terraform-plan.yml` | written |
| `.github/workflows/terraform-apply.yml` | written |
| `.github/workflows/frontend-deploy.yml` | written |
| `docs/architecture.md` | written |
| `docs/runbook.md` | written |
| `CLAUDE.md`, `README.md`, `HANDOVER.md` | written |
| `.claude/settings.json` | allowlists for terraform + aws read-only commands |

### Validation status

- `terraform fmt -recursive -check` — ✓ clean
- `terraform validate` (per stack: bootstrap, shared, dev, prod) — ✓ all four pass
- `tflint --recursive` — not run locally (CI workflow runs it on every PR)
- Local commit `7245473` — created
- GitHub remote configured: `https://github.com/tech-savy-dev/member-mitra-infra.git`
- Push: **pending** — GitHub repo doesn't exist yet (manual step below)

---

## Next Step (two manual gates, owner-only)

### Gate 1: Create the GitHub repo + push

1. Browser → https://github.com/new
2. Owner: `tech-savy-dev`
3. Name: `member-mitra-infra`
4. **Private**
5. **DO NOT** add README / .gitignore / license (we have them locally)
6. Create.
7. Terminal:
   ```bash
   cd ~/projects/Gym-Billing/member-mitra-infra
   git push -u origin main
   ```

### Gate 2: AWS credentials + bootstrap apply

Provide:
- AWS account ID
- Local AWS credentials configured (`aws sts get-caller-identity` works
  and shows an admin user/role).
- Confirm `tech-savy-dev` is the right GitHub org for OIDC trust.

Then run:

```bash
cd ~/projects/Gym-Billing/member-mitra-infra/bootstrap
terraform init
terraform apply -var "github_org=tech-savy-dev"
terraform output -json > bootstrap-outputs.json
```

Capture the outputs and update the placeholders in:
- `shared/backend.tf`, `environments/dev/backend.tf`,
  `environments/prod/backend.tf` → `bucket` field with the real
  `tfstate_bucket_name`.
- `environments/dev/main.tf`, `environments/prod/main.tf` →
  `data.terraform_remote_state.shared.config.bucket` field with the
  same bucket name.
- `.github/workflows/terraform-plan.yml` → `AWS_ROLE` with
  `oidc_role_dev_arn`.
- `.github/workflows/terraform-apply.yml` → both role ARNs.
- `.github/workflows/frontend-deploy.yml` → both role ARNs +
  `APP_REPO` if different from `tech-savy-dev/member-mitra`.
- `environments/dev/terraform.tfvars` and
  `environments/prod/terraform.tfvars` → set `kms_key_arn` from
  `kms_key_arn` output, and `alarm_email` if you want SNS.

Then commit + push the wired values and CI takes over.

---

## Context Files for Next Step

1. `bootstrap/main.tf` — what gets created on the manual apply
2. `bootstrap/README.md` — step-by-step procedure
3. `docs/runbook.md` — "Bootstrap a fresh AWS account" section
4. `.github/workflows/terraform-apply.yml` — references OIDC role ARN
   that bootstrap creates

---

## Manual verification still owed

1. Bootstrap applied successfully against the real AWS account.
2. Outputs (bucket name + KMS key ARN + OIDC role ARNs) captured.
3. `shared/backend.tf` and `environments/*/backend.tf` updated with the
   real bucket name.
4. `shared/` `terraform init` succeeds (backend connects to S3).
5. `shared/` `terraform plan` runs without errors.
6. `environments/dev/` `terraform init` + `terraform plan` succeed.
7. SSM SecureString values populated via `aws ssm put-parameter` for
   dev environment.
8. ACM cert validation records present in Route53.
9. CloudFront distribution deployed and `dev.membermitra.com` resolves.
10. Frontend deploy workflow successfully syncs app dist to S3 and
    invalidates CloudFront cache.

---

## Known Open Items

- Hosted zone for `membermitra.com` is currently at Namecheap. Either:
  - (a) Transfer DNS authority to Route53 (recommended for clean
    Terraform-managed records), OR
  - (b) Keep authority at Namecheap and manually add the CNAMEs Route53
    needs (cert validation, CloudFront ALIAS). Less clean but works.
  - Decision needed from user.
- No CloudWatch alarms wired to a notification channel yet. After
  bootstrap + first apply, set the `alarm_email` variable in
  `environments/*/terraform.tfvars` to enable SNS email alerts.
- `_stubs/` (RDS / Cognito / Lambda for future Supabase migration) is
  NOT included by design. Add only when actually migrating.

---

## Patterns to Reuse (validated in this repo)

1. **Single shared VPC, two envs.** Public subnets shared by NAT
   gateways; private subnets tagged per env. IAM policies restrict
   each env's role to its own subnet tag.
2. **Bootstrap is local + manual.** Everything else flows through CI.
   This avoids the OIDC chicken-and-egg.
3. **Secret slots in Terraform, values via CLI.** `aws ssm put-parameter`
   out-of-band keeps state + git clean.
4. **CloudFront `us-east-1` cert + `ap-south-1` bucket.** Use a separate
   provider alias `aws.us_east_1` for ACM resources.
5. **Per-env IAM role with same name pattern.** Trust policy bound to
   the exact GitHub ref and environment, no wildcards.

---

## Build order (matches CLAUDE.md §8)

- [x] Scaffold repo + write modules + docs
- [ ] Bootstrap (manual apply) ← **YOU ARE HERE**
- [ ] `shared/` plan + apply
- [ ] `environments/dev/` plan + apply
- [ ] Populate dev SSM secrets out-of-band
- [ ] Verify `dev.membermitra.com` end-to-end (deploy a build, smoke test)
- [ ] `environments/prod/` plan + apply (manual approval gate)
- [ ] Populate prod SSM secrets
- [ ] Verify `membermitra.com` apex end-to-end
- [ ] Wire app repo's release workflow to dispatch `frontend-deploy.yml`
