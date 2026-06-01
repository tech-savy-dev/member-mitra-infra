# HANDOVER

## Current Status

**dev environment LIVE.** Bootstrap + shared + dev all applied to AWS
account `677450898543` (ap-south-1). `https://dev.membermitra.com`
serves the production React build, talking to Mumbai Supabase backend.

### Resources live (43 total)

| Stack | Resources | Cost/mo |
|---|---|---|
| bootstrap | 17 (S3 state, DDB lock, KMS, OIDC, IAM roles) | ~$1 |
| shared | 22 (VPC, IGW, 6 subnets, 5 route tables, 2 endpoints, Route53 zone) | ~$0.50 |
| dev | 24 (S3, CloudFront, ACM, WAFv2, Route53 records, 8 SSM slots, alarm, log group, SNS) | ~$8 |
| **Total** | **63** | **~$10/mo** |

### Key identifiers

- AWS account: `677450898543`
- Region: `ap-south-1` (Mumbai)
- State bucket: `member-mitra-tfstate-62dc6b00`
- KMS key: `arn:aws:kms:ap-south-1:677450898543:key/58f1877b-8725-488c-a48e-c1032cae9f01`
- OIDC role (dev): `arn:aws:iam::677450898543:role/member-mitra-infra-dev`
- OIDC role (prod): `arn:aws:iam::677450898543:role/member-mitra-infra-prod`
- VPC: `vpc-0f26ab5b76c2240c7`
- Route53 zone: hosted at AWS, NS records below
- dev CloudFront: `E19O6WT9BXKV65` (d10abt48upt1to.cloudfront.net)
- dev S3 bucket: `member-mitra-dev-app`

### Route53 nameservers (for delegation at Namecheap)

```
ns-1178.awsdns-19.org
ns-1715.awsdns-22.co.uk
ns-433.awsdns-54.com
ns-659.awsdns-18.net
```

`dev.membermitra.com` is already delegated to Route53 via 4 NS records
at Namecheap. Prod apex needs nameserver migration at Namecheap (see
"Next Step").

### Repo state

- ✓ All modules written + validated (`terraform fmt + validate` clean)
- ✓ Pushed to https://github.com/tech-savy-dev/member-mitra-infra
- ✓ Bootstrap applied
- ✓ Shared applied (VPC + Route53 zone)
- ✓ dev applied (frontend + secrets + monitoring + WAF)
- ✓ App build deployed to S3 + CloudFront invalidated
- ✓ `https://dev.membermitra.com` returns HTTP 200 with React app

### Validation status

- `terraform fmt -recursive -check` — ✓ clean
- `terraform validate` — ✓ all 4 stacks pass
- Real apply outcomes — ✓ all 63 resources up and verified
- `dig + curl dev.membermitra.com` — ✓ resolves + serves app
- TLS cert — ✓ valid (ACM, us-east-1)

---

## Next Step — Populate dev secrets + prod apex DNS

### A. Populate dev SSM SecureStrings (so future Lambdas can read them)

All 8 SSM slots currently have placeholder values. Real values via:

```bash
aws ssm put-parameter --overwrite --type SecureString \
  --name /membermitra/dev/supabase/url --value "https://mokhzrbtknnfcurpjylq.supabase.co"

aws ssm put-parameter --overwrite --type SecureString \
  --name /membermitra/dev/supabase/anon_key --value "<from supabase dashboard>"

# ... repeat for the other 6 slots
```

Frontend at `dev.membermitra.com` already has these embedded via
`.env.production.local` at build time, so SSM values only matter once
backend workloads (Lambda, ECS) get added.

### B. Prod apex DNS — pick a path

Prod uses `membermitra.com` apex + `www.membermitra.com`. Three options:

**B1. Full DNS migration to Route53 (cleanest)**:
- Copy ALL current Namecheap records (Resend MX/TXT/SPF/DKIM, etc.) into
  the Route53 zone first.
- Switch nameservers at Namecheap from `dns1.registrar-servers.com` etc.
  to the 4 AWS NS shown above.
- Wait ~24h propagation.
- Apply `environments/prod/`.

**B2. Subdomain delegation for `app`** (analogous to dev):
- Change `primary_domain` in prod to `app.membermitra.com`.
- Delegate `app` subdomain via 4 NS records at Namecheap (same pattern
  as dev).
- Keep Resend SMTP at Namecheap untouched.
- Compromise: URL is `app.membermitra.com` not bare `membermitra.com`.

**B3. Skip prod for now** — dev is enough for launch beta. Add prod
when you have paying customers.

### C. Wire frontend-deploy workflow (optional, automates this manual deploy)

Set GitHub repo secrets:
- `VITE_SUPABASE_URL` (Mumbai project URL)
- `VITE_SUPABASE_ANON_KEY`
- `APP_REPO_PAT` (only if app repo is private)

Then merging to `main` on the app repo can trigger a deploy via
`repository_dispatch` (small workflow tweak in the app repo).

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
