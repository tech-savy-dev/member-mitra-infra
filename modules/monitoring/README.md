# modules/monitoring

Bare-minimum observability for V1. Designed to be expanded as actual
workloads appear.

## What it creates

- SNS topic `member-mitra-<env>-alarms` (email subscription if
  `alarm_email` is set).
- CloudWatch alarm: CloudFront 5xx error rate > 5% for 10 min.
- Reserved log group `/member-mitra/<env>/app` for future Lambda /
  migrated workloads. 30-day retention.

## Confirm SNS subscription

After first apply, AWS sends a confirmation email to `alarm_email`.
Click the link. Subscription stays pending until confirmed; alarms
won't fire to you.

## Monthly cost

| Item | $/mo |
|---|---|
| 1 alarm | $0.10 |
| SNS email (low volume) | <$0.01 |
| Log group (no logs ingested yet) | $0 |
| **Subtotal** | **~$0.10** |

Costs scale linearly with alarms added. Keep the alarm set tight.
