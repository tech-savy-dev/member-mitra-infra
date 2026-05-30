# CLAUDE.md — member-mitra-infra

## 0. AGENT OPERATING INSTRUCTIONS (TOKEN OPTIMIZATION)

Same checkpoint workflow as the app repo. On `Resume from handover /loop`:

1. Read `HANDOVER.md` → identify the current step + target files.
2. Read ONLY the listed files. Don't scan the rest of the repo.
3. Complete one logical step. Don't bleed into the next.
4. Update `HANDOVER.md` with `Completed:` + `Next Step:` + `Context Files:`.
5. Exit with the standard "Step Complete & State Saved" message.

Token discipline: terse responses, batched tool calls, no narration of
internal thought. State the action, take the action, report the result.

---

## 1. What this repo is

Terraform monorepo for AWS infrastructure backing MemberMitra. The app
itself ships from the sister repo (`tech-savy-dev/member-mitra`). This
repo owns: frontend hosting (S3 + CloudFront), DNS, WAF, secrets
plumbing, observability, CI auth.

**The backend stays on Supabase Cloud.** No RDS, no Cognito, no Lambda
in this repo. If you ever migrate the backend off Supabase, that work
goes here, but as a separate PR series — not implicitly.

---

## 2. Tech stack (do not substitute)

| Layer | Tool | Why |
|---|---|---|
| IaC | Terraform 1.7+ | industry standard, AWS provider mature |
| Cloud | AWS | user choice; ap-south-1 (Mumbai) for app, us-east-1 for CloudFront cert/WAF |
| State | S3 + DynamoDB lock | standard, ~$0.50/month |
| Secrets | SSM Parameter Store (SecureString) | cheaper than Secrets Manager at this scale |
| CI | GitHub Actions + OIDC | no long-lived AWS keys |
| Linting | tflint + checkov | catch drift + insecure patterns at PR time |

If you need a tool not listed, STOP and ask.

---

## 3. Architecture rules (non-negotiable)

### 3.1 One VPC, two environments

- A single VPC carries dev + prod. Saves ~$45/mo on NAT.
- Isolation is enforced via subnet tags + security groups + IAM scoping.
- Dev IAM roles MUST NOT be able to read/write prod subnet resources.
- If a future regulatory requirement says "separate VPCs", split then.
  Don't preemptively split now.

### 3.2 Folder discipline

- `bootstrap/` — one-time, manual, local apply. Never run from CI.
- `modules/` — reusable. Each module is self-contained: `main.tf`,
  `variables.tf`, `outputs.tf`, `README.md`. No cross-module references
  except via inputs/outputs.
- `environments/{dev,prod}/` — composes modules with env-specific
  parameters. No `resource` blocks here, only `module` blocks +
  `data` lookups.
- `shared/` — VPC + Route53 zone + OIDC provider. Lives in its own
  state file. Both envs read its outputs via
  `data "terraform_remote_state"`.

### 3.3 Tagging

Every resource MUST carry these tags (set via provider `default_tags`):

```hcl
default_tags {
  tags = {
    Project     = "member-mitra"
    Environment = var.environment  # dev | prod | shared
    ManagedBy   = "terraform"
    Repo        = "tech-savy-dev/member-mitra-infra"
  }
}
```

### 3.4 Naming

Format: `member-mitra-<env>-<resource-type>-<name>`.
Examples: `member-mitra-dev-s3-app`, `member-mitra-prod-cf-app`.

### 3.5 State

- State is in S3, NEVER local. Every env directory has a `backend.tf`.
- Lock via DynamoDB. Never disable locking.
- State files contain secrets — the S3 bucket has KMS + versioning +
  public access blocked + no public listing.

### 3.6 No hard-coded ARNs

- Use `data` sources or `terraform_remote_state` outputs.
- The only exception is the bootstrap state bucket name itself, since
  it's the chicken-and-egg seed.

### 3.7 One concern per PR

- One module change per PR. No mega-PRs touching VPC + frontend +
  monitoring at once.

---

## 4. Testing discipline

Pre-PR checklist (also enforced by CI):

```bash
terraform fmt -recursive -check
terraform validate    # per stack
tflint --recursive
checkov --directory . --quiet --soft-fail
```

`terraform apply` ONLY via CI on merge to `main`. Local apply is
forbidden except for `bootstrap/` (admin creds, one-time).

For prod applies, the workflow requires a manual approval via the
"production" GitHub Environment.

---

## 5. Secrets

- NEVER in `.tf` files.
- NEVER in `*.tfvars` (the `.gitignore` enforces this — only `.example`
  variants are tracked).
- ALWAYS in SSM Parameter Store as `SecureString`.
- Terraform creates parameter slots with placeholder values; real values
  are written out-of-band via `aws ssm put-parameter --overwrite`.
- Rotation procedure in `docs/runbook.md`.

---

## 6. Cost discipline

- Every module documents its monthly cost estimate in its `README.md`.
- PRs that add > $20/month to the steady-state bill MUST flag it in the
  description.
- Target ceiling for the full V1 perimeter (dev + prod): **~$50/month**
  AWS, on top of Supabase + Resend.

---

## 7. Disaster recovery

- State bucket has versioning ON — recoverable for 90 days.
- Frontend S3 buckets have versioning ON — accidentally-deleted assets
  are recoverable for 30 days.
- DNS records are in Terraform — recoverable by `terraform apply`.
- See `docs/runbook.md` for the full recovery procedures.

---

## 8. Build order

Follow this sequence. Don't jump ahead.

1. **Bootstrap** — S3 state bucket + DynamoDB lock + KMS key + OIDC
   provider + GitHub Actions IAM roles. Manual local apply, once.
2. **`shared/`** — VPC + Route53 hosted zone.
3. **`environments/dev/`** — frontend + secrets + monitoring + WAF.
4. **`environments/prod/`** — same as dev but apex domain.
5. **CI workflows** — terraform-plan, terraform-apply, frontend-deploy.

After Step 5 the app repo can dispatch frontend builds to S3 + CloudFront.

---

## 9. Communication style

- Terse. State the change, show the diff, report the result.
- Code/command answers > prose paragraphs.
- Tables for comparisons.
- Don't restate the plan file — reference it: "per plan §B.3".
- Save status to `HANDOVER.md`, not chat.
