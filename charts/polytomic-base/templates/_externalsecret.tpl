{{/*
Renders one ExternalSecret CR per entry in .values.secrets.external.entries.
Each data entry is either a bare string (k8sKey == remoteKey) or a map with
k8sKey and optional remoteKey (defaults to k8sKey). source.type selects the
store defaults: asm (AWS Secrets Manager) or gcpsm (Google Secret Manager).
*/}}
{{- define "polytomic-base.externalsecret" -}}
{{- $ctx := . -}}
{{- $defaults := .values.secrets.external.defaults | default dict }}
{{- $apiVersion := .values.secrets.external.apiVersion | default "external-secrets.io/v1" }}
{{- range $es := .values.secrets.external.entries }}
{{- $source := $es.source.type | default "asm" }}
{{- $path := required (printf "secrets.external.entries[%s].source.path is required" $es.name) $es.source.path }}
---
apiVersion: {{ $apiVersion }}
kind: ExternalSecret
metadata:
  name: {{ $es.name }}
  namespace: {{ $ctx.root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" $ctx | nindent 4 }}
spec:
  refreshInterval: {{ $es.refreshInterval | default $defaults.refreshInterval | default "1h" }}
  secretStoreRef:
  {{- if eq $source "asm" }}
    name: {{ ($defaults.asm).storeName | default "aws-secrets-manager" }}
    kind: {{ ($defaults.asm).storeKind | default "ClusterSecretStore" }}
  {{- else if eq $source "gcpsm" }}
    name: {{ ($defaults.gcpsm).storeName | default "gcp-secret-manager" }}
    kind: {{ ($defaults.gcpsm).storeKind | default "ClusterSecretStore" }}
  {{- else }}
    {{- fail (printf "unsupported secrets.external.source.type: %s (asm or gcpsm)" $source) }}
  {{- end }}
  target:
    name: {{ $es.name }}
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
  {{- range $entry := $es.data }}
    {{- if kindIs "string" $entry }}
    - secretKey: {{ $entry | quote }}
      remoteRef:
        key: {{ $path | quote }}
        property: {{ $entry | quote }}
    {{- else if kindIs "map" $entry }}
    {{- $k8sKey := required (printf "secrets.external.entries[%s].data[].k8sKey is required" $es.name) $entry.k8sKey }}
    - secretKey: {{ $k8sKey | quote }}
      remoteRef:
        key: {{ $path | quote }}
        property: {{ $entry.remoteKey | default $k8sKey | quote }}
    {{- else }}
    {{- fail (printf "secrets.external.entries[%s].data[] must be a string or map" $es.name) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
