# `config:` keys

`config:` is a flat map of environment variables written verbatim to the app ConfigMap and
inherited by every role and every spawned Job. The chart sets no defaults; the application's
own defaults apply for anything unset. This page lists the keys Polytomic supports setting
here. Other keys pass through, but are not covered by this chart's documentation.

Secret-valued settings never go in `config:`. They come from a secret source; see the
README.

## Authentication

| key | default | purpose |
|---|---|---|
| `ROOT_USER` | | Email of the first user, who can invite others. Set on first install. |
| `AUTH_METHODS` | application default | Comma-separated login methods to enable, e.g. `google`, `sso`. |
| `SINGLE_PLAYER` | `false` | Evaluation mode with no authentication. Never in production. |
| `GOOGLE_CLIENT_ID` | | Google OAuth client ID. The secret goes in a secret source as `GOOGLE_CLIENT_SECRET`. |
| `WORKOS_CLIENT_ID` | | WorkOS client ID for SSO. `WORKOS_API_KEY` goes in a secret source. |

## Operation

| key | default | purpose |
|---|---|---|
| `ENV` | | Environment label attached to logs and telemetry. |
| `LOG_LEVEL` | `info` | `trace`, `debug`, `info`, `warn`, `error`. |
| `AUTO_MIGRATE` | `true` | Run database migrations on startup. |
| `DEFAULT_ORG_FEATURES` | | Comma-separated feature flags enabled for every organization. |
| `TELEMETRY_URL` | `https://ping.polytomic.com/` | Polytomic license and telemetry service. Leave unset. |
| `INTERNAL_URL` | `auth.url` | URL other components use to reach the app inside the cluster. |
| `PUBLIC_URL` | | Public URL for static assets when served from a CDN. |

## Performance

| key | default | purpose |
|---|---|---|
| `QUERY_WORKERS` | `10` | Worker goroutines used when querying. |
| `SYNC_CONCURRENCY` | number of CPUs | Maximum concurrent sync executions per pod. |
| `SYNC_RETRY_ERRORS` | `false` | Retry sync execution errors automatically. |
| `TX_BUFFER_SIZE` | `1000` | Cache transaction buffer size. |
| `DATABASE_POOL_SIZE` | application default | PostgreSQL connections per pod. `<ROLE>_ROLE_DATABASE_POOL_SIZE` overrides it for one role. |
| `DATABASE_IDLE_TIMEOUT` | `5s` | Idle PostgreSQL connection timeout. |
| `REDIS_POOL_SIZE` | application default | Redis connections per pod. |

## Observability

| key | default | purpose |
|---|---|---|
| `METRICS` | `false` | Submit runtime metrics to Datadog. |
| `TRACING` | `false` | APM tracing to Datadog. |
| `PROFILING` | `false` | Continuous profiling to Datadog. |
| `DD_ENV`, `DD_SERVICE` | | Datadog tags. `DD_AGENT_HOST` is set by the chart when `datadog.daemonset.enabled`; set it yourself when running your own agent. |

## Integrations

OAuth client IDs and other non-secret integration settings go here in `UPPER_CASE`, for
example `SALESFORCE_CLIENT_ID`, `HUBSPOT_CLIENT_ID`, `GOOGLEADS_DEVELOPER_TOKEN`. The matching
secrets (`*_CLIENT_SECRET`, API keys) go in a secret source.

## Reserved

The chart computes these and rejects them here: `DATABASE_URL`, `REDIS_URL`, `CACHE_URL`,
`KUBERNETES*`, `POLYTOMIC_URL`, `APP_URL`, `DEPLOYMENT`, `LOCAL_DATA`, `LOCAL_DATA_PATH`,
`AWS_REGION`, `DEFAULT_OPERATIONAL_BUCKET`, `RECORD_LOG_BUCKET`, `RECORD_LOG_REGION`,
`EXECUTION_LOG_BUCKET`, `EXECUTION_LOG_REGION`, `POLYTOMIC_USE_GCS`, `VECTOR_DAEMONSET`,
`SEND_LOGS`, `EXECUTION_LOGS_V2`, `INTERNAL_EXECUTION_LOGS`, the executor sizing keys set
through `runner.executors`, and `DD_AGENT_HOST` while `datadog.daemonset.enabled`.
