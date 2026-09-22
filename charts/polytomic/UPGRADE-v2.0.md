# Upgrade guide: 1.x to 2.0

2.0.0 replaces the 1.x chart from the `polytomic/on-premises` repository. It keeps the chart
name, so `helm upgrade` works on an existing release, but every 1.x values file must be
rewritten and every Deployment is recreated once. Plan a maintenance window.

The first part lists what changed. The second is how to do the upgrade.

## What changed

### Values shape

Roles are configured under `services.<role>` instead of top-level `web`, `sync`, `worker`,
`schemacache`, `scheduler`, `jobworker` and `healthcheck` blocks. `web` is now `app`.

| 1.x | 2.0 |
|---|---|
| `web.replicaCount` | `services.app.replicas` |
| `web.resources` | `services.app.resources` |
| `web.autoscaling` | `services.app.autoscaling` |
| `web.nodeSelector` / `tolerations` / `affinity` / `podAnnotations` | same keys under `services.app`, or `services.defaults` for all roles |
| `web.podSecurityContext` / `securityContext` | `podSecurityContext` / `securityContext` (global) or per role |
| `web.sidecarContainers` | `services.app.sidecarContainers` |
| `podDisruptionBudget` (global) | `services.<role>.podDisruptionBudget` |
| `service.port` | `services.app.service.port` (now `5100`, was `80`) |
| `imageRegistry`, `image.repository` | `image.registry`, `image.name` |
| `polytomic.deployment.name` | `polytomicDeploymentId` |
| `polytomic.auth.url` | `auth.url` |
| `polytomic.roles.<role>.*` | `runner.executors.<role>.*` (camelCase fields) |
| `polytomic.kubernetes.nodeSelectors` / `tolerations` (strings) | `runner.nodeSelectors` (map) / `runner.tolerations` (list) |
| `polytomic.sharedVolume.*` | `sharedVolume.*` (`volumeName` becomes `persistentVolume.name` / `persistentVolumeClaim.name`) |
| `polytomic.s3.operational_bucket` / `region` / `gcs` | `operationalBucket.{provider,name,region}` |
| `polytomic.vector.*`, `polytomic.datadog.*`, `polytomic.embeddedVector` | `vector.*`, `datadog.*`, `embeddedVector` |
| `externalPostgresql.host` / `port` / `username` / `database` / `sslMode` | `database.host` / `port` / `username` / `polytomicDatabase` / `sslmode` |
| `externalPostgresql.ssl`, `poolSize`, `idleTimeout`, `autoMigrate` | gone; set `config.DATABASE_POOL_SIZE`, `DATABASE_IDLE_TIMEOUT`, `AUTO_MIGRATE` |
| `externalPostgresql.existingSecret.{name,key}` | gone; the Secret named in `secrets.existing` must carry the `DATABASE_PASSWORD` key |
| `externalRedis.host` / `port` / `ssl` | `externalRedis.host` / `port` / `tls`; `externalRedis.auth: true` when a password is used |
| `externalRedis.poolSize` | gone; set `config.REDIS_POOL_SIZE` |
| `externalRedis.existingSecret.{name,key}` | gone; the Secret named in `secrets.existing` must carry the `REDIS_PASSWORD` key |
| `postgresql.auth.username` / `database` / `primary.persistence` | unchanged |
| `redis.architecture` / `master.persistence` | unchanged |
| `nfs-server-provisioner.*` | unchanged, but now `enabled: false` by default |
| `image.tag`, `image.pullPolicy`, `imagePullSecrets` | unchanged; `image.tag` is required |
| `nameOverride`, `fullnameOverride`, `healthProbes.*` | unchanged |
| `serviceAccount.create` / `annotations` / `name` | unchanged; `serviceAccount.automount` added |
| `service.type` | `services.app.service.type` |
| `ingress.annotations` / `hosts` / `tls` | unchanged shape; `enabled` now defaults to `false` and `className` is applied |
| `worker.replicaCount`, `sync.replicaCount` | `services.worker.replicas`, `services.sync.replicas` |
| `scheduler.*`, `schemacache.*`, `jobworker.*`, `healthcheck.*` | `services.<role>.*`; these roles now accept `replicas`, `autoscaling` and `podDisruptionBudget` too |
| `mcp.*` | `mcp.*` (see below) |

### Settings that were typed values are now `config:` keys

`polytomic.auth.root_user`, `single_player`, `methods`, `google_client_id`,
`workos_client_id`, `polytomic.log_level`, `env`, `default_org_features`, `query_workers`,
`sync_retry_errors`, `tx_buffer_size`, `metrics`, `tracing`, `externalPostgresql.poolSize`,
`idleTimeout`, `autoMigrate`, `polytomic.integrations` and `polytomic.extraEnv` are all gone.
Set the environment variable directly:

```yaml
config:
  ROOT_USER: you@example.com
  AUTH_METHODS: google
  LOG_LEVEL: info
  SALESFORCE_CLIENT_ID: "..."
```

`docs/config-keys.md` lists the supported keys.

`polytomic.field_change_tracking` and `polytomic.sync_workers` are gone with no replacement:
the application has no setting by either name, so the 1.x values had no effect.

### Secrets

The chart no longer renders a Secret and no longer reads any secret from values. These 1.x
values are gone: `polytomic.deployment.key`, `deployment.api_key`, `auth.google_client_secret`,
`auth.workos_api_key`, `s3.access_key_id`, `s3.secret_access_key`, `externalPostgresql.password`,
`externalRedis.password`, `postgresql.auth.password`, `redis.auth.password`, `secret.name`,
`extraSecrets`, and every secret in `polytomic.integrations`.

Secrets come from `secrets.existing[]` (Secrets you create) and `secrets.external.entries[]`
(ESO). The keys are the environment variable names: `DEPLOYMENT_KEY`, `DATABASE_PASSWORD`,
`REDIS_PASSWORD`, `GOOGLE_CLIENT_SECRET`, `WORKOS_API_KEY`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `SALESFORCE_CLIENT_SECRET`, and so on. `DATABASE_URL` and `REDIS_URL`
now contain `${DATABASE_PASSWORD}` / `${REDIS_PASSWORD}` placeholders the app expands at
startup.

### Bundled PostgreSQL and Redis

Both are off by default. When enabled they read the password from your Secret through
`postgresql.auth.existingSecret` and `redis.auth.existingSecret`, and never generate one.
Bitnami applies the PostgreSQL password only on first initialisation: if you move an
existing bundled database onto a Secret with a different password, run
`ALTER USER polytomic WITH PASSWORD '...'` yourself.

### Resource names and labels

Resources are `<release>-polytomic-<role>` with `app.kubernetes.io/name: polytomic` and
`app.kubernetes.io/component: <role>`. 1.x used `app.kubernetes.io/name: polytomic-<role>`.
Deployment selectors are immutable, so Helm deletes and recreates every Deployment on the
first 2.0 upgrade. The web Service is `<release>-polytomic-app` on port 5100 (was
`<release>-polytomic` on port 80).

### Ingress

Off by default, with no ingress class. `ingress.className` is now applied to the Ingress;
in 1.x it was declared but never rendered, so clusters relied on their default class. Set
`ingress.enabled: true`, `ingress.className` and your hosts explicitly.

### RBAC

The app ServiceAccount is bound to a namespaced Role (pods, jobs) instead of a ClusterRole.
The cluster-scoped ClusterRole and ClusterRoleBinding from 1.x are removed by the upgrade.

### NetworkPolicy

`networkPolicy.postgresql`, `networkPolicy.redis`, `allowExternalHttps` and
`externalHttpsCidrs` are gone. Egress to bundled databases is automatic; all other egress is
listed in `networkPolicy.egress`. See `docs/network-policy.md`. The 1.x policy selected no
pods, so enabling it in 2.0 is the first time it takes effect.

### Runner scheduling

`runner.tolerations` is a list of `{key, value, effect}` and the chart renders the string the
app parses. The 1.x string format documented in `values.yaml` (`key:Equal:value:effect`) was
wrong and produced an `Exists` toleration with a bad effect.

### Logging and APM

`vector.daemonset.enabled`, `datadog.daemonset.enabled` and `embeddedVector.enabled` default
to `false`. When off, no `vector.dev/include` label, `VECTOR_DAEMONSET`, `SEND_LOGS` or
`DD_AGENT_HOST` is set. Each DaemonSet reads `DEPLOYMENT_KEY` and any static bucket keys from
its own `secrets.existing` list.

### MCP

`mcp.image.repository` is `mcp.image.name`; `mcp.replicaCount`, `mcp.port`, `mcp.resources`
and `mcp.service` move under `mcp.services.http`; `mcp.apiVersion` is
`mcp.polytomic.apiVersion`. MCP now has its own ServiceAccount with no RBAC, its own
`mcp.config` and `mcp.secrets`, and advertises `auth.url` as the OAuth server (1.x advertised
the in-cluster Service URL, which browsers cannot reach). Set `mcp.polytomic.publicOrigin`.

### Removed

- `development` mode.
- `polytomic.vector.daemonset.serviceAccount.roleArn` (put the
  `eks.amazonaws.com/role-arn` annotation in `vector.daemonset.serviceAccount.annotations`).
- `minio` values (the subchart was never wired).
- Summary CronJobs are new and disabled; enable `cronjobs.jobs.*` if you want the emails.

## Doing the upgrade

1. **Back up** PostgreSQL. If you run the bundled database, snapshot its PVC.
2. **Create the Secret(s)** holding every value listed under Secrets above. For bundled
   databases, `DATABASE_PASSWORD` and `REDIS_PASSWORD` must be the passwords the databases
   already have.
3. **Rewrite `values.yaml`** with the mapping tables above. Start from the chart's
   `values.yaml` rather than editing the 1.x file. Move typed settings into `config:`.
4. **Render and compare** before touching the cluster:
   ```
   helm template polytomic oci://ghcr.io/polytomic/charts/polytomic --version 2.0.0 -f values.yaml > new.yaml
   helm get manifest polytomic > old.yaml
   ```
   Check `DATABASE_URL`, `REDIS_URL`, the bucket variables and every `config:` key in the
   ConfigMap against the 1.x Secret's `stringData`.
5. **Expect downtime.** Every Deployment is recreated, and the Service name and port change.
   Update anything that addressed `<release>-polytomic:80` directly.
6. **Upgrade:**
   ```
   helm upgrade polytomic oci://ghcr.io/polytomic/charts/polytomic --version 2.0.0 -f values.yaml
   ```
7. **Verify** the app pods reach Running, `helm get manifest` shows the Role (not a
   ClusterRole), and a sync execution spawns a Job that mounts `polytomic-data`.
8. **Executor sizing.** `runner.executors.task` ships the 1.x defaults. If you had changed
   `polytomic.roles.*`, carry those numbers over; otherwise nothing changes.
9. **Ingress.** Re-enable it and set `className`. If routing stops working, the cluster's
   default class was doing the work in 1.x.
10. **Clean up.** The 1.x chart-rendered `<release>-polytomic-config` Secret is deleted by
    the upgrade. Delete any 1.x ClusterRoleBinding that survives if you had renamed it.
