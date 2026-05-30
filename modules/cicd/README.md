# modules/cicd

Thin pass-through for the GitHub Actions OIDC role created by bootstrap.
Env stacks `data` source the existing role and re-export its ARN so the
workflow files can reference it via env-stack outputs.

When V1 tightens least-privilege, this module is where the env-scoped
policy attachments go (instead of bootstrap's broad `PowerUserAccess`).

## Monthly cost

$0 — IAM roles are free.
