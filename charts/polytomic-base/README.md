# polytomic-base

Library chart holding the templates shared by Polytomic's application charts. It renders
nothing on its own; a consumer chart declares it as a dependency and calls its templates.

## Contract

Every template, and every naming or data helper, takes a context dict, never the Helm root:

| key | value |
|---|---|
| `root` | the consumer's `$` |
| `values` | the values block to render: `.Values` for the primary component, `.Values.<block>` for a secondary one |
| `name` | component prefix, `""` for the primary component |

```
{{- include "polytomic-base.deployment" (dict "root" . "values" .Values "name" "") }}
{{- include "polytomic-base.deployment" (dict "root" . "values" .Values.mcp "name" "mcp") }}
```

Names derive from the dict: resources are `<fullname>[-<name>]-<service>`, the ConfigMap is
`<fullname>[-<name>]-config`, and `app.kubernetes.io/name` is `<chart>[-<name>]` so a
NetworkPolicy selects one component's pods only.

Four helpers take their own arguments instead: `polytomic-base.image`
`{registry, image, tag}`, `polytomic-base.componentImage` `{block, default}` (empty
`registry` / `tag` in `block` inherit from `default`), and the internal `serviceDefault` /
`serviceList` `{ctx, svc, key}`.

### Required consumer helpers

The lib dispatches to helpers named `<Chart.Name>[.<name>].<helper>`. A consumer defines all
three for every `name` it renders; empty bodies are fine.

| helper | returns |
|---|---|
| `reservedConfigKeys` | space-separated keys rejected in `config:` |
| `extraConfigData` | YAML lines appended to the ConfigMap data |
| `extraEgress` | YAML list of NetworkPolicy egress rules appended after `networkPolicy.egress` |

### `tpl` context

`services.defaults.initContainers`, `volumes` and `volumeMounts`, and their per-service
counterparts, are concatenated (defaults first) and rendered through `tpl` with the context
dict. Inside a snippet, `.` is the dict: call lib helpers with `.` and reach the Helm root as
`.root`.

```yaml
services:
  defaults:
    initContainers:
      - name: wait
        image: busybox
        env:
          - name: URL
            valueFrom:
              configMapKeyRef:
                name: '{{ include "polytomic-base.configmapName" . }}'
                key: SOME_URL
```

### Checksum

`polytomic-base.deployment` stamps `checksum/config` with the SHA-256 of
`polytomic-base.configmapData` for its dict. Render the ConfigMap with
`polytomic-base.configmap` (or from `configmapData`) so the hash matches what is deployed.

## Templates

| define | renders |
|---|---|
| `polytomic-base.configmap` | the ConfigMap |
| `polytomic-base.deployment` | one Deployment per enabled `services.<name>` |
| `polytomic-base.service` | one Service per enabled service with a `service` block |
| `polytomic-base.hpa` | one HPA per service with `autoscaling.enabled` |
| `polytomic-base.pdb` | one PDB per service with `podDisruptionBudget.enabled` |
| `polytomic-base.ingress` | an Ingress with per-path `service` / `port` routing |
| `polytomic-base.networkpolicy` | a NetworkPolicy for the component's pods |
| `polytomic-base.serviceaccount` | the ServiceAccount |
| `polytomic-base.externalsecret` | one ExternalSecret per `secrets.external.entries[]` |

## Values the lib reads

`image`, `imagePullSecrets`, `nameOverride`, `fullnameOverride`, `revisionHistoryLimit`,
`serviceAccount`, `podSecurityContext`, `securityContext`, `config`, `secrets`, `healthProbes`,
`services`, `networkPolicy`, `ingress`. See `test-consumer/values.yaml` for the full shape.

### Secrets

The lib never renders a Secret. `secrets.external.entries[]` become ExternalSecrets
(`secrets.external.apiVersion` defaults to `external-secrets.io/v1`; `source.type` is `asm` or
`gcpsm`), and `secrets.existing[]` names Secrets that already exist. Both are attached to every
pod with `envFrom`. `polytomic-base.secretName` returns the first external entry, else the
first existing one, and fails when neither is set.

## Tests

Library charts cannot be unit-tested directly. `test-consumer/` is an unpublished chart that
consumes the lib and carries the lib's helm-unittest suites:

```
helm dependency build test-consumer
helm unittest test-consumer
```

Re-run `helm dependency build` after editing the lib; the consumer renders the vendored copy.
