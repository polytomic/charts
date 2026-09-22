{{/*
Templates and naming helpers in this library take a context dict, not the
Helm root:

  root    the chart's `$`
  values  the values block to render (.Values for the primary component,
          .Values.<block> for a secondary one)
  name    component prefix; "" for the primary component

Exceptions with their own arguments: image {registry,image,tag},
componentImage {block,default}, serviceDefault and serviceList {ctx,svc,key}.

Consumer-defined helpers are dispatched as "<Chart.Name>[.<name>].<helper>".
Every consumer defines reservedConfigKeys, extraConfigData and extraEgress
for each name it renders (empty bodies are fine).
*/}}

{{/*
Chart name, or nameOverride, with the component name appended.
*/}}
{{- define "polytomic-base.name" -}}
{{- $base := default .root.Chart.Name .values.nameOverride -}}
{{- if .name -}}
{{- printf "%s-%s" $base .name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Fully qualified name. fullnameOverride replaces the release/chart part; the
component name is still appended.
*/}}
{{- define "polytomic-base.fullname" -}}
{{- $base := "" -}}
{{- if .values.fullnameOverride -}}
{{- $base = .values.fullnameOverride -}}
{{- else -}}
{{- $chart := default .root.Chart.Name .values.nameOverride -}}
{{- if contains $chart .root.Release.Name -}}
{{- $base = .root.Release.Name -}}
{{- else -}}
{{- $base = printf "%s-%s" .root.Release.Name $chart -}}
{{- end -}}
{{- end -}}
{{- if .name -}}
{{- printf "%s-%s" $base .name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Chart name + version for the helm.sh/chart label.
*/}}
{{- define "polytomic-base.chart" -}}
{{- printf "%s-%s" .root.Chart.Name .root.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. `app.kubernetes.io/part-of` is the consumer chart name.
*/}}
{{- define "polytomic-base.labels" -}}
helm.sh/chart: {{ include "polytomic-base.chart" . }}
{{ include "polytomic-base.selectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: {{ .root.Chart.Name }}
{{- end }}

{{/*
Selector labels. The name label carries the component prefix so a
NetworkPolicy selects one component's pods and not another's.
*/}}
{{- define "polytomic-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "polytomic-base.name" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Service account name. Honors serviceAccount.create / serviceAccount.name.
*/}}
{{- define "polytomic-base.serviceAccountName" -}}
{{- if .values.serviceAccount.create }}
{{- default (include "polytomic-base.fullname" .) .values.serviceAccount.name }}
{{- else }}
{{- default "default" .values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Construct registry/image[:tag]. Pass dict of registry, image, tag.
*/}}
{{- define "polytomic-base.image" -}}
{{- $registry := .registry | default "" -}}
{{- $image := .image | default "" -}}
{{- $tag := .tag | default "" -}}
{{- $name := $image -}}
{{- if $registry -}}
{{- $name = printf "%s/%s" $registry $image -}}
{{- end -}}
{{- if $tag -}}
{{- printf "%s:%s" $name $tag -}}
{{- else -}}
{{- $name -}}
{{- end -}}
{{- end }}

{{/*
Resolve a secondary image block against a primary one. Pass dict of block
and default; empty registry or tag in block inherit from default.
*/}}
{{- define "polytomic-base.componentImage" -}}
{{- $block := .block | default dict -}}
{{- include "polytomic-base.image" (dict "registry" ($block.registry | default .default.registry) "image" ($block.name | default .default.name) "tag" ($block.tag | default .default.tag)) -}}
{{- end }}

{{/*
Primary secret name. Precedence: first ESO entry > first existing entry.
Fails if neither is configured.
*/}}
{{- define "polytomic-base.secretName" -}}
{{- if .values.secrets.external.entries -}}
{{- (index .values.secrets.external.entries 0).name -}}
{{- else if .values.secrets.existing -}}
{{- (index .values.secrets.existing 0).name -}}
{{- else -}}
{{- fail "no primary secret: set secrets.external.entries or secrets.existing" -}}
{{- end -}}
{{- end }}

{{/*
Canonical ConfigMap name: <fullname>-config.
*/}}
{{- define "polytomic-base.configmapName" -}}
{{- printf "%s-config" (include "polytomic-base.fullname" .) -}}
{{- end }}

{{/*
Helper-name prefix for consumer dispatch: "<Chart.Name>[.<name>]".
*/}}
{{- define "polytomic-base.consumer" -}}
{{- if .name -}}
{{- printf "%s.%s" .root.Chart.Name .name -}}
{{- else -}}
{{- .root.Chart.Name -}}
{{- end -}}
{{- end }}

{{/*
Per-service replace-on-set fallback to services.defaults.<key>.
Used for nodeSelector / affinity / tolerations.

Usage:
  {{ include "polytomic-base.serviceDefault" (dict "ctx" . "svc" $svc "key" "nodeSelector") }}
*/}}
{{- define "polytomic-base.serviceDefault" -}}
{{- $perSvc := index .svc .key -}}
{{- $default := index .ctx.values.services.defaults .key -}}
{{- if $perSvc -}}
{{- toYaml $perSvc -}}
{{- else if $default -}}
{{- toYaml $default -}}
{{- end -}}
{{- end }}

{{/*
Additive concat of services.defaults.<key> + services.<name>.<key> for the
list-valued keys initContainers, volumes and volumeMounts. Defaults come
first. Result is YAML-encoded; callers render it through `tpl` with the
context dict so values may embed lib includes.

Usage:
  {{- $ic := include "polytomic-base.serviceList" (dict "ctx" . "svc" $svc "key" "initContainers") }}
*/}}
{{- define "polytomic-base.serviceList" -}}
{{- $defaults := index .ctx.values.services.defaults .key | default list -}}
{{- $perSvc := index .svc .key | default list -}}
{{- $all := concat $defaults $perSvc -}}
{{- if $all -}}
{{- toYaml $all -}}
{{- end -}}
{{- end }}

{{/*
Flat .values.config iteration with reserved-key validation. Reserved keys
come from the consumer's "<consumer>.reservedConfigKeys" helper, a
space-separated string. Skips only kindIs "invalid" values so false / 0
reach the ConfigMap.
*/}}
{{- define "polytomic-base.configmapBaseData" -}}
{{- $reservedHelper := printf "%s.reservedConfigKeys" (include "polytomic-base.consumer" .) -}}
{{- $reserved := splitList " " (include $reservedHelper . | trim) -}}
{{- range $key, $value := .values.config }}
{{- if has $key $reserved }}
{{- fail (printf "config.%s is a reserved key — supplied by chart-computed config or chart-owned mechanism" $key) }}
{{- end }}
{{- if not (kindIs "invalid" $value) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Complete ConfigMap data: base data followed by the consumer's
"<consumer>.extraConfigData". The Deployment checksum hashes this same
output, so consumers must render their ConfigMap from it.
*/}}
{{- define "polytomic-base.configmapData" -}}
{{- $base := include "polytomic-base.configmapBaseData" . | trim -}}
{{- $extra := include (printf "%s.extraConfigData" (include "polytomic-base.consumer" .)) . | trim -}}
{{- $parts := list -}}
{{- if $base }}{{ $parts = append $parts $base }}{{ end -}}
{{- if $extra }}{{ $parts = append $parts $extra }}{{ end -}}
{{- join "\n" $parts -}}
{{- end }}

{{/*
ConfigMap resource.
*/}}
{{- define "polytomic-base.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "polytomic-base.configmapName" . }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" . | nindent 4 }}
    app.kubernetes.io/component: config
data:
  {{- include "polytomic-base.configmapData" . | nindent 2 }}
{{- end }}
