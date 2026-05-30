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

- `terraform fmt -recursive -check` — pending (run after files settle)
- `terraform validate` — pending (requires `terraform init` per stack)
- `tflint --recursive` — pending
- No commits to GitHub yet

---

## Next Step

**Provide AWS credentials and apply bootstrap.**

Required from the user:

1. AWS account ID
2. IAM admin user OR AWS SSO profile name with admin rights
3. GitHub organization name (assumed `tech-savy-dev`; confirm)
4. Confirm domain `membermitra.com` is in Route53 (or transfer plan)

Once credentials are configured locally:

```bash
cd ~/projects/Gym-Billing/member-mitra-infra/bootstrap
terraform init
terraform apply
terraform output > ../shared/.bootstrap-outputs.tfvars.example
```

The outputs populate the S3 bucket name + KMS key ARN + OIDC role ARNs
used by `shared/backend.tf`, `environments/*/backend.tf`, and the GitHub
Actions workflows.

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
