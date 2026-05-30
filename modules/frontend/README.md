# modules/frontend

S3 site bucket + CloudFront distribution + ACM cert (us-east-1) + WAFv2
ACL + Route53 ALIAS records. One instance per environment.

## Monthly cost (estimate)

| Item | $/mo |
|---|---|
| S3 storage (~50 MB of build output) | <$0.01 |
| CloudFront requests (~50k/mo per active gym × ~10 active gyms early) | ~$0.50 |
| CloudFront data egress (small at this stage) | ~$1-3 |
| WAFv2 ACL + managed rule subscriptions (2 rule groups + 1 custom) | ~$6 |
| ACM cert | $0 (public) |
| Route53 alias queries | included in zone cost |
| **Subtotal per env** | **~$7-10** |

Both envs combined: ~$15-20/mo at low usage. Scales gracefully.

## Provider requirement

This module needs a second AWS provider aliased to `us_east_1`:

```hcl
provider "aws" { region = "ap-south-1" }
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "frontend" {
  source = "../../modules/frontend"
  providers = { aws.us_east_1 = aws.us_east_1 }
  environment    = "dev"
  primary_domain = "dev.membermitra.com"
  hosted_zone_id = data.terraform_remote_state.shared.outputs.hosted_zone_id
}
```

## After applying

1. Build the app: `cd ../member-mitra && npm run build`.
2. Sync: `aws s3 sync dist/ s3://<bucket>/ --delete`.
3. Invalidate: `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`.

The `frontend-deploy.yml` workflow automates steps 2-3 once the bucket
name + distribution ID are wired in via outputs.
