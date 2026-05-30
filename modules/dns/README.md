# modules/dns

Route53 public hosted zone for `membermitra.com`. Single zone, both envs
share it. Subdomain records (apex, www, dev) are created in
`modules/frontend` per environment.

## Monthly cost

| Item | $/mo |
|---|---|
| 1 public hosted zone | $0.50 |
| ~10 record sets | ~$0.40 (first 1B queries free) |
| **Subtotal** | **~$1** |

## After applying

Take the `name_servers` output and set them at the registrar (Namecheap).
Without this step, DNS resolution doesn't work. The zone exists in
Route53 but the world won't see it.

If the domain currently has Resend SMTP / membermitra DNS records at
Namecheap, copy those to Route53 BEFORE switching the nameservers,
otherwise email will break.

## Reusing

```hcl
module "dns" {
  source      = "../modules/dns"
  domain_name = "membermitra.com"
}
```

Instantiated ONCE in `shared/main.tf`.
