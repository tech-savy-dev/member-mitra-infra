# modules/secrets

Creates SSM Parameter Store SecureString slots, one per known secret.
Terraform owns the slot; the actual value is written out-of-band.

## Why this split

Putting real secret values in `.tfvars` or state means they end up in
git history + S3 state files. Even with SSE-KMS, that's a needless
attack surface. With this module:

- Slot exists with `PLACEHOLDER_SET_VIA_AWS_CLI`.
- `lifecycle.ignore_changes = [value]` keeps Terraform from "fixing" the
  real value back to the placeholder on every plan.
- Real value lives only in SSM (KMS-encrypted) + the application that
  reads it.

## Populating values

```bash
aws ssm put-parameter \
  --name /membermitra/dev/supabase/anon_key \
  --type SecureString \
  --value "eyJhbG..." \
  --overwrite
```

See `docs/runbook.md` for the full secrets sync procedure on first
deploy.

## Monthly cost

| Item | $/mo |
|---|---|
| 8 standard parameters | $0 (first 10k standard parameters free) |
| API calls (low) | <$0.05 |
| **Subtotal** | **~$0** |

If we ever flip to Advanced parameters (>4 KB values, higher throughput),
costs jump to $0.05 per parameter. Not yet needed.
