# polytomic

Helm chart for the Polytomic data integration platform. One chart deploys the Polytomic
application and, optionally, the MCP server. Polytomic runs its own environments from this
chart, and it is the chart customers install on-premises.

```
helm install polytomic oci://ghcr.io/polytomic/charts/polytomic --version 2.0.0 -f values.yaml
```

Upgrading from the 1.x on-premises chart: read [UPGRADE-v2.0.md](UPGRADE-v2.0.md) first.

## What it deploys

- **Deployments**, one per role, configured under `services.<role>`: `app` (web, receives
  ingress), `scheduler`, `healthcheck`, `schemacache`, `sync`, `jobworker`, `worker`.
  Each has `enabled`, `replicas`, `resources`, `autoscaling`, `podDisruptionBudget`, and
  the per-pod knobs listed below.
- **ConfigMap** `<fullname>-config` with the non-secret environment, attached to every pod.
- **ServiceAccount**, **Role** and **RoleBinding** (pods and jobs in the release namespace)
  so the app can spawn per-task Jobs.
- **Service** for `app`, **Ingress** (opt-in), **HPA** and **PDB** per service (opt-in),
  **NetworkPolicy** (opt-in).
- **Shared volume**: a ReadWriteMany PVC (or PV + PVC, or emptyDir) mounted on every role,
  CronJob and spawned Job.
- **ExternalSecrets** for `secrets.external.entries` (requires ESO).
- **CronJobs** for the weekly and daily sync summary emails (opt-in).
- **MCP server** under `mcp:` (opt-in): its own Deployment, Service, ConfigMap,
  ServiceAccount, secret sources, Ingress and NetworkPolicy.
- **Vector DaemonSet** and **Datadog agent DaemonSet** (opt-in) for log routing and APM.
- Bundled **PostgreSQL**, **Redis** and **NFS provisioner** subcharts (opt-in) for trial
  installs.

## Required values

| value | purpose |
|---|---|
| `image.tag` | release to run, e.g. `rel2026.09.18` |
| `polytomicDeploymentId` | deployment identifier from Polytomic |
| `auth.url` | public URL of the install |
| `operationalBucket.name` (+ `provider`, `region`) | S3 or GCS bucket for logs and exports |
| `database.*` | external PostgreSQL, unless `postgresql.enabled` |
| `externalRedis.*` | external Redis, unless `redis.enabled` |
| a secret source | `secrets.existing[]` or `secrets.external.entries[]` |

Render fails with a message naming the missing value.

## Secrets

The chart never renders a Secret and no secret value belongs in a values file. Secrets
reach the pods through `envFrom` from two sources, used alone or together:

- `secrets.external.entries[]`: the chart emits an ExternalSecret per entry and the External
  Secrets Operator writes the Secret. See [docs/secrets-aws.md](docs/secrets-aws.md) and
  [docs/secrets-gcp.md](docs/secrets-gcp.md).
- `secrets.existing[]`: Secrets you created in the release namespace.

Keys the app reads from a secret source include `DEPLOYMENT_KEY`, `DATABASE_PASSWORD`,
`REDIS_PASSWORD`, `GOOGLE_CLIENT_SECRET`, `WORKOS_API_KEY`, `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` (only without workload identity), and integration credentials.
The first source listed is the primary Secret handed to spawned Jobs; the rest follow via
`KUBERNETES_EXTRA_SECRETS`.

## Configuration

Non-secret settings go in the flat `config:` map and land in the ConfigMap verbatim.
[docs/config-keys.md](docs/config-keys.md) lists the keys Polytomic supports. Keys the chart
computes (`DATABASE_URL`, `KUBERNETES_*`, the bucket vars, and so on) are reserved and
rejected at render time.

Bucket access is assumed to come from the environment: IRSA on EKS or Workload Identity on
GKE through `serviceAccount.annotations`. Static keys go in a secret source.

### Shared volume

| `sharedVolume.mode` | renders |
|---|---|
| `dynamic` | a PVC against `sharedVolume.dynamic.storageClassName` (empty = cluster default) |
| `static` | a PV for `sharedVolume.static.{driver,volumeHandle,volumeAttributes}` and a PVC bound to it |
| `emptyDir` | no shared storage; `LOCAL_DATA` is off |

`nfs-server-provisioner.enabled: true` adds an `nfs` StorageClass for `dynamic` mode on
clusters without ReadWriteMany storage.

### Per-pod settings

`services.defaults` applies to every role; `services.<role>` overrides it. `nodeSelector`,
`affinity` and `tolerations` replace; `podAnnotations` and `podLabels` add; `initContainers`,
`volumes` and `volumeMounts` concatenate (defaults first) and render through `tpl`. Per role:
`strategy`, `minReadySeconds`, `terminationGracePeriodSeconds`, `priorityClassName`,
`topologySpreadConstraints`, `lifecycle`, `env`, `extraEnv`, `extraEnvFrom`,
`sidecarContainers`, `image.{registry,name,tag}`, `podSecurityContext`, `securityContext`.

### Spawned Jobs

`runner.*` configures the per-task Jobs the app spawns: `nodeSelectors`, `tolerations`
(`key`, optional `value`, `effect`), `imagePullSecret`, and per-role sizing under
`runner.executors.<role>`. Roles other than `task` inherit `task`'s values at runtime.

### MCP

Set `mcp.enabled: true`. `mcp.polytomic.baseUrl` defaults to the in-cluster app Service and
`mcp.polytomic.authServerUrl` to `auth.url`; set `mcp.polytomic.publicOrigin` to the public
MCP URL. MCP has its own `mcp.config`, `mcp.secrets`, `mcp.ingress`, `mcp.networkPolicy`
and `mcp.services.http`. It never receives the app's config or secrets.

### Logging and APM

`vector.daemonset.enabled` runs Vector on every node, routing record, execution and audit
logs into `operationalBucket`; `vector.managedLogs` also forwards non-record logs to
Polytomic's Datadog. `datadog.daemonset.enabled` runs the Datadog agent for APM.
`embeddedVector.enabled` selects the in-pod Vector process instead of the DaemonSet. Each
DaemonSet has its own `secrets.existing` list and never sees the app's secrets.

### NetworkPolicy

`networkPolicy.enabled` restricts the app pods. Egress to the bundled Postgres and Redis is
added automatically; everything else goes in `networkPolicy.egress`. See
[docs/network-policy.md](docs/network-policy.md).

## Images

`image.registry` is the one registry for every Polytomic image. `mcp.image`,
`vector.daemonset.image` and `datadog.daemonset.image` inherit `registry` and `tag` from
`image` when left empty.

## Development

```
make tools          # helm-unittest, helm-values-schema-json
make deps           # vendor the lib and subcharts (re-run after editing the lib)
make lint
make test
make template FIXTURE=bundled
make schema         # regenerate values.schema.json after changing values.yaml
```

`values.schema.json` is generated; edit the `# @schema` annotations in `values.yaml` and run
`make schema`. Cross-field rules live in `polytomic.validateConfig` in `templates/_helpers.tpl`.
