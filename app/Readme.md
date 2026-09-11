# Consolidated workbook → `data.json`

```
BA fills consolidated template
        ↓ upload
s3://<bucket>/consolidated/*.xlsx
        ↓ EventBridge  "Object Created"
Lambda  (lambda_function.lambda_handler)
        ↓
s3://<bucket>/output/data.json            ← const EMPLOYEES = [ … ];
s3://<bucket>/output/last-run-report.json ← row counts + rejected rows
```

## Column mapping

| Consolidated header | JSON key | Rule |
|---|---|---|
| `login` | `login` | Trimmed. **Blank → row rejected** (it's the downstream join key). |
| `name` | `name` | Trimmed, whitespace collapsed. Blank → rejected. |
| `email` | `email` | Lowercased, format-validated. Blank/malformed → rejected. |
| `Manager` | `manager` | Trimmed. (`Manager ACF2` is read but unused.) |
| *(derived)* | `market` | From `MARKET_SOURCE_COLUMN` via `MARKET_MAP`. **See open question below.** |
| *(derived)* | `marketTag` | Same value as `market`. |
| `Last Active Date` | `active` | `true` if within `ACTIVE_WINDOW_DAYS` (default 90). Configurable. |
| *(constant)* | `tokens` | `0.0` |

Unused in the JSON but read and available: `ACF2`, `Manager ACF2`, `Title`,
`Department`, `Company`, `Employee Type`, `Cost Centre`.

Headers are matched case- and whitespace-insensitively, with aliases
(`Cost Center`/`Cost Centre`, `Email Address`/`email`, …), so small wording
drift in the BA's template won't break the run.

## Two open questions

**1. Where does `market` come from?** There is no market column in the
consolidated table. `HKIT` reads like a market + function code, so the default
assumes it's derived from **Business Category** through an explicit map:

```json
MARKET_MAP = {"Hong Kong IT": "HKIT", "Philippines IT": "PHIT", "Singapore IT": "SGIT"}
```

Point `MARKET_SOURCE_COLUMN` at `company`, `department`, or `cost centre`
instead if one of those is the real source. With no map configured, the source
value passes through uppercased. Set `MARKET_STRICT=true` once the map is
complete so an unmapped value rejects the row rather than emitting `""`.

**2. What does `active` actually mean?** Default is "used the tool in the last
90 days" (`ACTIVE_MODE=last_active_window`). If it means "still employed",
switch to `ACTIVE_MODE=employee_type`; if every row in the file is active by
definition, `ACTIVE_MODE=always_true`.

## Environment variables

| Variable | Default | Notes |
|---|---|---|
| `SOURCE_PREFIX` | `consolidated/` | Keys outside it are ignored. |
| `OUTPUT_BUCKET` | *(same as input)* | |
| `OUTPUT_KEY` | `output/data.json` | |
| `REPORT_KEY` | `output/last-run-report.json` | Empty string disables. |
| `SHEET_NAME` | *(first sheet)* | |
| `OUTPUT_FORMAT` | `js_const` | `js_const` → `const EMPLOYEES = […];`, `json` → plain array. |
| `JS_CONST_NAME` | `EMPLOYEES` | |
| `SORT_BY_LOGIN` | `true` | Stable ordering keeps diffs readable. |
| `ACTIVE_MODE` | `last_active_window` | `last_active_window` \| `always_true` \| `employee_type` |
| `ACTIVE_WINDOW_DAYS` | `90` | |
| `ACTIVE_IF_DATE_BLANK` | `false` | How to treat a blank Last Active Date. |
| `INACTIVE_EMPLOYEE_TYPES` | `terminated,leaver,inactive` | For `employee_type` mode. |
| `MARKET_SOURCE_COLUMN` | `business category` | |
| `MARKET_MAP` | `{}` | JSON object, matched case-insensitively. |
| `MARKET_DEFAULT` | *(empty)* | Fallback when nothing matches. |
| `MARKET_STRICT` | `false` | `true` → unmapped market rejects the row. |
| `DEFAULT_TOKENS` | `0.0` | |
| `DERIVE_LOGIN_FROM_EMAIL` | `false` | Blank login → email local part. Off by default. |
| `REQUIRE_EMAIL` | `true` | |
| `MAX_REJECT_RATIO` | `0.25` | Above this, **nothing is written** and the run fails. |
| `S3_SSE` | `AES256` | Or `aws:kms` with `S3_SSE_KMS_KEY_ID`. |
| `LOG_LEVEL` | `INFO` | |

## Guardrails worth knowing about

- **Nothing overwrites `data.json` on a bad run.** If more than
  `MAX_REJECT_RATIO` of rows fail validation — the usual symptom of a paste
  landing in the wrong columns — the Lambda raises and leaves the previous
  good file in place.
- **Duplicate logins reject rather than silently overwrite.** Two different
  people sharing a login is a data problem someone must see.
- **Recursion guard**: objects under the output prefix are skipped, so writing
  `data.json` into the same bucket can't re-trigger the function.
- **Emails are masked in CloudWatch logs** (`ju***@example.com`). The rejected-row
  report keeps them masked too.
- **Key-encoding fallback**: EventBridge and S3 notifications encode object keys
  differently; the handler tries both spellings before giving up, so filenames
  with spaces or `+` still resolve.

## Deploy

**Runtime** Python 3.12. **Handler** `lambda_function.lambda_handler`.
**Memory** 512 MB (1024 MB above ~20k rows). **Timeout** 60 s.

**Dependency** — `openpyxl` only. Either attach the AWS SDK for pandas managed
layer (it bundles openpyxl):

```
arn:aws:lambda:ap-southeast-1:336392948345:layer:AWSSDKPandas-Python312:<latest>
```

or build a 2 MB layer of your own:

```bash
mkdir -p layer/python && pip install openpyxl -t layer/python
cd layer && zip -r ../openpyxl-layer.zip python && cd ..
```

**Execution-role policy** (least privilege — note the separate read and write
prefixes):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:HeadObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET/consolidated/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET/output/*"
    }
  ]
}
```

Plus `AWSLambdaBasicExecutionRole`, and `kms:GenerateDataKey` on the key if the
bucket uses SSE-KMS.

**EventBridge rule** (requires EventBridge notifications enabled on the bucket):

```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": { "name": ["YOUR_BUCKET"] },
    "object": { "key": [{ "prefix": "consolidated/" }] }
  }
}
```

**Also worth having**: a CloudWatch alarm on the function's `Errors` metric. A
failed run is silent otherwise, and the dashboard just keeps serving yesterday's
`data.json`.

## Bucket hygiene

This file carries names, emails and reporting lines for real staff. Before the
first real upload: Block Public Access on, default encryption on, versioning on
(so a bad overwrite is recoverable), a lifecycle rule expiring old consolidated
uploads, and bucket policy limited to the BA's upload role and the Lambda role.
If `data.json` is served to a browser, whatever fronts it needs authentication —
an S3 object URL is a URL.

## Local test

```bash
pip install openpyxl
python test_local.py
```

Builds a sample workbook with deliberately broken rows (blank login, malformed
email, duplicate login, string dates, messy whitespace), runs the exact
transform the Lambda uses, prints the resulting `data.json`, and asserts the
mapping. Edit `HEADERS`/`ROWS` there to match a real file before deploying.