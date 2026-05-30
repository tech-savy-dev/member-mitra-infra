# Runbook

Common ops procedures. Keep this short.

## Bootstrap a fresh AWS account

1. Configure AWS CLI: `aws configure sso` (recommended) or
   `aws configure`. Verify: `aws sts get-caller-identity`.
2. `cd bootstrap`.
3. `terraform init`.
4. ```bash
   terraform apply \
     -var "github_org=tech-savy-dev" \
     -var "infra_repo=member-mitra-infra"
   ```
5. Capture outputs: `terraform output -json > bootstrap-outputs.json`.
6. Update these files with real values:
   - `shared/backend.tf` — `bucket`
   - `environments/dev/backend.tf` — `bucket`
   - `environments/prod/backend.tf` — `bucket`
   - `environments/dev/main.tf` — `data.terraform_remote_state.shared.config.bucket`
   - `environments/prod/main.tf` — same
   - `.github/workflows/terraform-plan.yml` — `AWS_ROLE`
   - `.github/workflows/terraform-apply.yml` — both role ARNs
   - `.github/workflows/frontend-deploy.yml` — both role ARNs
7. Commit + push the wired values.

## Populate / rotate a secret

Once. Per environment. After secrets module is applied (slots exist).

```bash
aws ssm put-parameter \
  --name /membermitra/dev/supabase/anon_key \
  --type SecureString \
  --value "eyJhbGc...real-key..." \
  --overwrite
```

`--overwrite` is required for rotation. Terraform's `ignore_changes`
prevents drift.

## Invalidate CloudFront cache (manual)

```bash
aws cloudfront create-invalidation \
  --distribution-id $(cd environments/dev && terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

Normally automated by `frontend-deploy.yml` — only needed for one-off
cache busts.

## Deploy a fresh frontend build (manual)

Workflow does this automatically. If you need to do it from a laptop:

```bash
cd ~/projects/Gym-Billing/member-mitra
npm run build

cd ~/projects/Gym-Billing/member-mitra-infra/environments/dev
BUCKET=$(terraform output -raw s3_bucket_name)
DIST=$(terraform output -raw cloudfront_distribution_id)

aws s3 sync ../../member-mitra/dist/ s3://$BUCKET/ --delete \
  --cache-control "public, max-age=31536000, immutable" \
  --exclude "index.html"
aws s3 cp ../../member-mitra/dist/index.html s3://$BUCKET/index.html \
  --cache-control "no-cache, no-store, must-revalidate"
aws cloudfront create-invalidation --distribution-id $DIST --paths "/*"
```

## Restore an S3 object from a previous version

```bash
aws s3api list-object-versions --bucket $BUCKET --prefix path/to/file
# Find the VersionId you want, then:
aws s3api copy-object \
  --copy-source "$BUCKET/path/to/file?versionId=<old-version-id>" \
  --bucket $BUCKET --key path/to/file
```

Then invalidate CloudFront for the path.

## Recover Terraform state from S3 versioning

State bucket has versioning ON; lookback window = 90 days.

```bash
aws s3api list-object-versions \
  --bucket <tfstate-bucket> \
  --prefix environments/dev/terraform.tfstate

# Restore a prior version:
aws s3api copy-object \
  --copy-source "<tfstate-bucket>/environments/dev/terraform.tfstate?versionId=<vid>" \
  --bucket <tfstate-bucket> \
  --key environments/dev/terraform.tfstate
```

Run `terraform plan` to confirm state matches reality.

## Add a new environment (e.g., uat)

1. Copy `environments/dev` to `environments/uat`.
2. Update `backend.tf` `key = "environments/uat/terraform.tfstate"`.
3. Update `Environment = "uat"` everywhere.
4. Update `primary_domain = "uat.membermitra.com"`.
5. Decide: reuse `member-mitra-infra-dev` role, or create
   `member-mitra-infra-uat` in `bootstrap/`.
6. Update `terraform-plan.yml` + `terraform-apply.yml` matrix to include
   the new stack.
7. PR, plan, merge.

## Respond to AWS account compromise

1. **Immediately** rotate the root password + every IAM user's
   credentials.
2. Delete the GitHub OIDC role(s); revoke any open Actions runs.
3. Re-apply `bootstrap/` with a fresh AWS account (or scrub the
   existing one).
4. Rotate every secret in SSM Parameter Store (the leaked role had
   SSM read permission via `PowerUserAccess`).
5. Audit CloudTrail for unauthorized API calls.
6. File a security incident with the post-mortem.

## Tear-down (don't)

If you truly must:

1. `terraform destroy` in `environments/prod`, then `dev`, then `shared`.
2. Empty + delete the state bucket (lose 90-day version history).
3. Delete the OIDC provider + roles.
4. Delete the KMS key (30-day window before final delete).

You cannot undo this. Take a backup of the state bucket first.
