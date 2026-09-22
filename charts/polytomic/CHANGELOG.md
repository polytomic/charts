# Changelog

All notable changes to the `polytomic` chart are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0]

First release from the `charts` repo. Consolidates the on-premises chart 1.x and Polytomic's
internal `polytomic` and `polytomic-mcp` charts into one chart built on `polytomic-base`.
Breaking for every 1.x values file; see `UPGRADE-v2.0.md`.

### Changed

- Values follow the `polytomic-base` shape: `services.<role>.*`, a flat `config:` map, and
  typed values only for what the chart computes. `web.*`, `sync.*`, `worker.*`,
  `polytomic.*`, `externalPostgresql.*` and `secret.*` are gone.
- Resources are named `<fullname>-<role>` with `app.kubernetes.io/component`; the web
  Service is `<fullname>-app` on port 5100. Deployment selectors change, so every Deployment
  is recreated once on upgrade.
- Secrets come only from `secrets.external.entries` (ESO) and `secrets.existing`; the chart
  no longer renders a Secret and no password or key is read from values.
- Bundled Postgres and Redis read `DATABASE_PASSWORD` / `REDIS_PASSWORD` from the customer's
  Secret via `auth.existingSecret`, and default to disabled.
- Ingress is off by default with no class; `ingress.className` is now applied.
- The app ServiceAccount is bound to a namespaced Role (pods, jobs) instead of a ClusterRole.
- `runner.tolerations` and `runner.nodeSelectors` are structured and rendered into the
  format the app parses.
- Executor sizing moves to `runner.executors.<role>` with the 1.x task defaults.
- The operational bucket is one `operationalBucket.{provider,name,region}` block.
- The Vector and Datadog DaemonSets, `embeddedVector`, and the `vector.dev/include` label are
  off by default and render nothing when off.
- Summary CronJobs exist but are disabled by default.
- The `development` all-in-one mode is removed.
- `kubeVersion` remains `>=1.34.0-0`.

### Added

- MCP under `mcp:` with its own ConfigMap, secret sources, ServiceAccount, ingress and
  NetworkPolicy, defaulting to the in-cluster app Service and `auth.url`.
- `sharedVolume.mode: emptyDir`, any CSI driver in `static` mode, configurable
  `accessModes` and `reclaimPolicy`.
- Per-service HPA `behavior`, PDB, `strategy`, probes, `startupProbe`, topology spread,
  lifecycle hooks, extra env and envFrom, per-service image overrides.
- Google Secret Manager as an ESO source (`source.type: gcpsm`).
- `values.schema.json` and helm-unittest suites.
