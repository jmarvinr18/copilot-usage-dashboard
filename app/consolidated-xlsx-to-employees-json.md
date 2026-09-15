# Consolidated employee workbook → data.json (S3 + EventBridge + Lambda)

Pipeline for turning the BA-maintained consolidated employee spreadsheet into the
`EMPLOYEES` array the dashboard consumes.

## Flow

```
BA copies raw export into the consolidated template
        ↓ upload
s3://<bucket>/consolidated/*.xlsx
        ↓ EventBridge "Object Created" (prefix: consolidated/)
Lambda (python3.12, openpyxl)
        ↓
s3://<bucket>/output/data.json             → const EMPLOYEES = [ … ];
s3://<bucket>/output/last-run-report.json  → counts + rejected rows
```

Streamlit was considered and dropped — the BA's copy-paste into the template is
the pre-process step, and S3 upload is the trigger.

## Consolidated table headers

`Last Active Date | ACF2 | login | name | email | Manager | Manager ACF2 | Title |
Department | Business Category | Company | Employee Type | Cost Centre`

## Mapping to the target JSON

| Header | JSON key | Rule |
|---|---|---|
| `login` | `login` | Join key. Blank → row rejected. |
| `name` | `name` | Trimmed, whitespace collapsed. |
| `email` | `email` | Lowercased, format-validated. |
| `Manager` | `manager` | `Manager ACF2` read but unused. |
| *derived* | `market` | From `MARKET_SOURCE_COLUMN` (default Business Category) via `MARKET_MAP`. |
| *derived* | `marketTag` | Mirrors `market`. |
| `Last Active Date` | `active` | Within `ACTIVE_WINDOW_DAYS` (default 90). |
| *constant* | `tokens` | `0.0` |

Unused but available: ACF2, Title, Department, Company, Employee Type, Cost Centre.

## Open decisions (Sep 2026)

1. **`market` source is unconfirmed.** No market column exists in the consolidated
   table. `HKIT` reads as market+function, so the implementation assumes Business
   Category translated through an explicit `MARKET_MAP`
   (`{"Hong Kong IT": "HKIT", …}`). Could equally be Company, Department or Cost
   Centre. Once the map is complete, set `MARKET_STRICT=true` so an unmapped value
   rejects the row instead of emitting `""`.
2. **`active` semantics.** Default is "used the tool within 90 days". If it means
   "still employed", switch `ACTIVE_MODE=employee_type`.

## Design choices worth preserving

- **Fail-closed on bad input.** If more than `MAX_REJECT_RATIO` (default 25%) of
  rows fail validation, the run raises and leaves the previous good `data.json`
  untouched. A paste landing one column off is the realistic failure mode, and
  silently publishing it is worse than not publishing.
- **Duplicate logins reject, never overwrite.** Login is what every downstream
  system matches on.
- **Recursion guard** on the output prefix — writing into the same bucket can't
  re-trigger the function.
- **Key-encoding fallback.** EventBridge and S3 notifications encode object keys
  differently (`+` vs space); the handler tries both spellings via `head_object`
  before failing. Filenames with spaces are common here.
- **Emails masked in CloudWatch logs** and in the rejected-row report.
- **Header matching is alias-driven** and case/whitespace-insensitive, so small
  drift in the BA's template wording doesn't break the run.
- **openpyxl only, no pandas** — read_only streaming mode, small layer, fast cold
  start. AWS SDK for pandas managed layer also works if already standardised on.

## Privacy note

This carries names, emails and reporting lines for real staff — a different
posture from the [Copilot usage dashboard](copilot-usage-metrics-dashboard.md),
which deliberately stayed org-aggregate. Required before first real upload: Block
Public Access, default encryption, versioning (recoverable bad overwrite),
lifecycle expiry on old consolidated uploads, bucket policy limited to the BA
upload role and the Lambda role, and authentication on whatever serves
`data.json` to a browser.

Also needed: a CloudWatch alarm on the function's `Errors` metric — silent
staleness is the real risk, same conclusion as the Copilot dashboard work.

## Artifacts

`lambda_function.py` (handler + pure `transform_rows` for unit testing),
`test_local.py` (builds a sample workbook with broken rows, asserts the mapping,
runs green offline), `README.md` (env var table, IAM policy, EventBridge rule
pattern, layer options).