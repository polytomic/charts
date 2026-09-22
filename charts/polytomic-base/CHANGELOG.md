# Changelog

All notable changes to `polytomic-base` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0]

First release from the `charts` repo. Breaking relative to the 0.1.0 lib in the app monorepo.

### Changed

- Templates and naming helpers take a context dict (`root`, `values`, `name`) instead of the
  Helm root, so one chart can render several components from different values blocks.
  `image`, `serviceDefault` and `serviceList` keep their own argument shapes.
- Consumer helpers are dispatched as `<Chart.Name>[.<name>].<helper>`; `extraConfigData` and
  `extraEgress` join `reservedConfigKeys` as required helpers.
- The Deployment `checksum/config` hashes the rendered ConfigMap data rather than including
  `templates/configmap.yaml`.
- `app.kubernetes.io/name` carries the component prefix (`<chart>[-<name>]`).
- `secrets.inCluster` is renamed `secrets.existing`.

### Added

- `polytomic-base.configmap` and `polytomic-base.configmapData`.
- `secrets.external.apiVersion` (default `external-secrets.io/v1`).
- `gcpsm` as a `secrets.external.entries[].source.type`.
- `services.defaults.volumes` and `volumeMounts`, concatenated with per-service entries and
  rendered through `tpl`.
- NetworkPolicy egress hook via the consumer's `extraEgress` helper.
- `polytomic-base.componentImage` for secondary image blocks that inherit from `image`.
- `test-consumer/` chart with the lib's unit tests.
