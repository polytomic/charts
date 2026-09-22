{{/*
All helpers take the lib context dict (root / values / name). See
charts/polytomic-base/README.md.
*/}}

{{/* ---------------------------------------------------------------------
Context construction
--------------------------------------------------------------------- */}}

{{/*
Values for the app component with the shared volume prepended to
services.defaults and the Vector label added when the DaemonSet is on.
Returns nothing; mutates the dict passed as .target.
*/}}
{{- define "polytomic.decorateAppValues" -}}
{{- $v := .target -}}
{{- $ctx := .ctx -}}
{{- $defaults := $v.services.defaults -}}
{{- $_ := set $defaults "volumes" (concat (list (include "polytomic.sharedVolume" $ctx | fromYaml)) ($defaults.volumes | default list)) -}}
{{- $_ := set $defaults "volumeMounts" (concat (list (include "polytomic.sharedVolumeMount" $ctx | fromYaml)) ($defaults.volumeMounts | default list)) -}}
{{- if $ctx.root.Values.vector.daemonset.enabled -}}
{{- include "polytomic.forceVectorLabel" $v -}}
{{- end -}}
{{- end }}

{{/*
Set vector.dev/include=true on every service's podLabels (per-service labels
render last, so this wins over any opt-out there). Mutates the dict.
*/}}
{{- define "polytomic.forceVectorLabel" -}}
{{- $label := dict "vector.dev/include" "true" -}}
{{- range $name, $svc := .services -}}
{{- if and (ne $name "defaults") (kindIs "map" $svc) -}}
{{- $_ := set $svc "podLabels" (mergeOverwrite (deepCopy ($svc.podLabels | default dict)) $label) -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Values for the MCP component: naming and pull settings copied from the
root so MCP resources sit beside the app's, the image resolved against
image.*, and the Vector label added when the DaemonSet is on. Mutates .target.
*/}}
{{- define "polytomic.decorateMcpValues" -}}
{{- $v := .target -}}
{{- $rv := .ctx.root.Values -}}
{{- $_ := set $v "nameOverride" $rv.nameOverride -}}
{{- $_ := set $v "fullnameOverride" $rv.fullnameOverride -}}
{{- $_ := set $v "imagePullSecrets" $rv.imagePullSecrets -}}
{{- $_ := set $v "revisionHistoryLimit" $rv.revisionHistoryLimit -}}
{{- $img := $v.image | default dict -}}
{{- $_ := set $v "image" (dict "registry" ($img.registry | default $rv.image.registry) "name" ($img.name | default "polytomic-mcp") "tag" ($img.tag | default $rv.image.tag) "pullPolicy" $rv.image.pullPolicy) -}}
{{- if $rv.vector.daemonset.enabled -}}
{{- include "polytomic.forceVectorLabel" $v -}}
{{- end -}}
{{- end }}

{{/* ---------------------------------------------------------------------
Postgres and Redis
--------------------------------------------------------------------- */}}

{{- define "polytomic.databaseHost" -}}
{{- if .root.Values.postgresql.enabled -}}
{{- required "postgresql.fullnameOverride is required when postgresql.enabled" .root.Values.postgresql.fullnameOverride -}}
{{- else -}}
{{- .root.Values.database.host -}}
{{- end -}}
{{- end }}

{{- define "polytomic.databasePort" -}}
{{- if .root.Values.postgresql.enabled -}}5432{{- else -}}{{ .root.Values.database.port | toString }}{{- end -}}
{{- end }}

{{- define "polytomic.databaseUsername" -}}
{{- if .root.Values.postgresql.enabled -}}{{ .root.Values.postgresql.auth.username }}{{- else -}}{{ .root.Values.database.username }}{{- end -}}
{{- end }}

{{- define "polytomic.databaseName" -}}
{{- if .root.Values.postgresql.enabled -}}{{ .root.Values.postgresql.auth.database }}{{- else -}}{{ .root.Values.database.polytomicDatabase }}{{- end -}}
{{- end }}

{{/*
Database URL. Password is interpolated at pod start from DATABASE_PASSWORD,
supplied by a secret source (and read by the bundled subchart from the same
Secret).
*/}}
{{- define "polytomic.databaseUrl" -}}
{{- $sslmode := "require" -}}
{{- if .root.Values.postgresql.enabled -}}
{{- $sslmode = "disable" -}}
{{- else -}}
{{- $sslmode = .root.Values.database.sslmode | default "require" -}}
{{- end -}}
{{- printf "postgres://%s:${DATABASE_PASSWORD}@%s:%s/%s?sslmode=%s" (include "polytomic.databaseUsername" .) (include "polytomic.databaseHost" .) (include "polytomic.databasePort" .) (include "polytomic.databaseName" .) $sslmode -}}
{{- end }}

{{- define "polytomic.redisHost" -}}
{{- if .root.Values.redis.enabled -}}
{{- printf "%s-master" (required "redis.fullnameOverride is required when redis.enabled" .root.Values.redis.fullnameOverride) -}}
{{- else -}}
{{- .root.Values.externalRedis.host -}}
{{- end -}}
{{- end }}

{{- define "polytomic.redisPort" -}}
{{- if .root.Values.redis.enabled -}}6379{{- else -}}{{ .root.Values.externalRedis.port | toString }}{{- end -}}
{{- end }}

{{/*
Redis URL. With auth (always on for the bundled subchart), ${REDIS_PASSWORD}
is interpolated at pod start from a secret source.
*/}}
{{- define "polytomic.redisUrl" -}}
{{- $r := .root.Values.externalRedis -}}
{{- $scheme := "redis" -}}
{{- $auth := $r.auth -}}
{{- if .root.Values.redis.enabled -}}
{{- $auth = true -}}
{{- else if $r.tls -}}
{{- $scheme = "rediss" -}}
{{- end -}}
{{- if $auth -}}
{{- printf "%s://:${REDIS_PASSWORD}@%s:%s" $scheme (include "polytomic.redisHost" .) (include "polytomic.redisPort" .) -}}
{{- else -}}
{{- printf "%s://%s:%s" $scheme (include "polytomic.redisHost" .) (include "polytomic.redisPort" .) -}}
{{- end -}}
{{- end }}

{{/*
Names of every configured secret source, for cross-checks.
*/}}
{{- define "polytomic.secretSourceNames" -}}
{{- $names := list -}}
{{- range .values.secrets.external.entries }}{{ $names = append $names .name }}{{ end -}}
{{- range .values.secrets.existing }}{{ $names = append $names .name }}{{ end -}}
{{- join " " $names -}}
{{- end }}

{{/* ---------------------------------------------------------------------
Operational bucket
--------------------------------------------------------------------- */}}

{{- define "polytomic.bucketName" -}}
{{- .root.Values.operationalBucket.name | trimPrefix "s3://" | trimPrefix "gs://" -}}
{{- end }}

{{- define "polytomic.bucketIsGcs" -}}
{{- if eq .root.Values.operationalBucket.provider "gcs" }}true{{ end -}}
{{- end }}

{{/*
DEFAULT_OPERATIONAL_BUCKET: scheme://name[?region=...].
*/}}
{{- define "polytomic.operationalBucketUrl" -}}
{{- $b := .root.Values.operationalBucket -}}
{{- if include "polytomic.bucketIsGcs" . -}}
{{- printf "gs://%s" (include "polytomic.bucketName" .) -}}
{{- else if $b.region -}}
{{- printf "s3://%s?region=%s" (include "polytomic.bucketName" .) $b.region -}}
{{- else -}}
{{- printf "s3://%s" (include "polytomic.bucketName" .) -}}
{{- end -}}
{{- end }}

{{/* ---------------------------------------------------------------------
Shared volume
--------------------------------------------------------------------- */}}

{{- define "polytomic.sharedVolumeIsPvc" -}}
{{- if ne .root.Values.sharedVolume.mode "emptyDir" }}true{{ end -}}
{{- end }}

{{/*
Pod volume for the shared data directory: a PVC or an emptyDir by mode.
*/}}
{{- define "polytomic.sharedVolume" -}}
name: polytomic-data
{{- if include "polytomic.sharedVolumeIsPvc" . }}
persistentVolumeClaim:
  claimName: {{ .root.Values.sharedVolume.persistentVolumeClaim.name }}
{{- else }}
emptyDir: {}
{{- end }}
{{- end }}

{{/*
Container mount for the shared data directory.
*/}}
{{- define "polytomic.sharedVolumeMount" -}}
name: polytomic-data
mountPath: {{ .root.Values.sharedVolume.mountPath }}
{{- with .root.Values.sharedVolume.subPath }}
subPath: {{ . }}
{{- end }}
{{- end }}

{{/* ---------------------------------------------------------------------
Runner
--------------------------------------------------------------------- */}}

{{/*
Role -> executor env-var prefix. The scheduler role uses *_ROLE rather than
*_EXECUTOR (matches addRoleFlags in services/polytomic/config/config.go).
Tags are named {ROLE}_TASK_EXECUTOR_TAGS (TASK_EXECUTOR_TAGS for task).
*/}}
{{- define "polytomic.executorPrefixes" -}}
task: TASK_EXECUTOR
bulk: BULK_EXECUTOR
ingest: INGEST_EXECUTOR
proxy: PROXY_EXECUTOR
scheduler: SCHEDULER_ROLE
{{- end }}

{{/*
Pull secret name for spawned Jobs: runner.imagePullSecret, else
imagePullSecrets[0].name, else empty.
*/}}
{{- define "polytomic.runnerImagePullSecret" -}}
{{- $r := .root.Values.runner | default dict -}}
{{- if $r.imagePullSecret -}}
{{- $r.imagePullSecret -}}
{{- else if .root.Values.imagePullSecrets -}}
{{- (index .root.Values.imagePullSecrets 0).name -}}
{{- end -}}
{{- end }}

{{/*
Env vars for the per-task Jobs the runner spawns, from .Values.runner. Emits
only what is set.
*/}}
{{- define "polytomic.runnerConfigData" -}}
{{- $runner := .root.Values.runner | default dict -}}
{{- with $runner.nodeSelectors }}
{{- $pairs := list -}}
{{- range $k, $v := . -}}{{- $pairs = append $pairs (printf "%s=%s" $k $v) -}}{{- end }}
KUBERNETES_NODE_SELECTORS: {{ join "," $pairs | quote }}
{{- end }}
{{- with $runner.tolerations }}
{{- $parts := list -}}
{{- range . -}}
{{- if not .key }}{{- fail "runner.tolerations[].key is required" }}{{- end -}}
{{- if not .effect }}{{- fail "runner.tolerations[].effect is required" }}{{- end -}}
{{- if .value -}}
{{- $parts = append $parts (printf "%s=%s:%s" .key .value .effect) -}}
{{- else -}}
{{- $parts = append $parts (printf "%s:%s" .key .effect) -}}
{{- end -}}
{{- end }}
KUBERNETES_TOLERATIONS: {{ join "," $parts | quote }}
{{- end }}
{{- $prefixes := include "polytomic.executorPrefixes" . | fromYaml -}}
{{- $fields := dict "cpu" "CPU" "memoryReservation" "MEMORY_RESERVATION" "memoryMaximum" "MEMORY_MAXIMUM" "memoryMega" "MEMORY_MEGA" "ephemeralStorageRequest" "EPHEMERAL_STORAGE_REQUEST" "ephemeralStorageMaximum" "EPHEMERAL_STORAGE_MAXIMUM" "databasePoolSize" "DATABASE_POOL_SIZE" "redisPoolSize" "REDIS_POOL_SIZE" "cleanupDelaySeconds" "CLEANUP_DELAY_SECONDS" -}}
{{- $executors := $runner.executors | default dict -}}
{{- range $role := (list "task" "bulk" "ingest" "proxy" "scheduler") -}}
{{- $cfg := index $executors $role -}}
{{- if $cfg -}}
{{- $prefix := index $prefixes $role -}}
{{- range $vk, $sfx := $fields -}}
{{- $val := index $cfg $vk -}}
{{- if $val }}
{{ printf "%s_%s" $prefix $sfx }}: {{ $val | quote }}
{{- end -}}
{{- end -}}
{{- if $cfg.tags }}
{{ ternary "TASK_EXECUTOR_TAGS" (printf "%s_TASK_EXECUTOR_TAGS" (upper $role)) (eq $role "task") }}: {{ $cfg.tags | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/* ---------------------------------------------------------------------
App component: consumer helpers dispatched by polytomic-base
--------------------------------------------------------------------- */}}

{{/*
Keys forbidden in .Values.config: chart-computed or chart-owned.
*/}}
{{- define "polytomic.reservedConfigKeys" -}}
{{- $keys := list "DATABASE_URL" "REDIS_URL" "CACHE_URL" "KUBERNETES" "KUBERNETES_NAMESPACE" "KUBERNETES_IMAGE" "KUBERNETES_CONFIGMAP" "KUBERNETES_SECRET" "KUBERNETES_SERVICE_ACCOUNT" "KUBERNETES_VOLUME" "KUBERNETES_MOUNT_PATH" "KUBERNETES_EXTRA_SECRETS" "KUBERNETES_IMAGE_PULL_SECRET" "KUBERNETES_NODE_SELECTORS" "KUBERNETES_TOLERATIONS" "POLYTOMIC_URL" "APP_URL" "DEPLOYMENT" "LOCAL_DATA" "LOCAL_DATA_PATH" "AWS_REGION" "DEFAULT_OPERATIONAL_BUCKET" "RECORD_LOG_BUCKET" "RECORD_LOG_REGION" "EXECUTION_LOG_BUCKET" "EXECUTION_LOG_REGION" "POLYTOMIC_USE_GCS" "VECTOR_DAEMONSET" "SEND_LOGS" "EXECUTION_LOGS_V2" "INTERNAL_EXECUTION_LOGS" -}}
{{- /* DD_AGENT_HOST is the chart's only while its own agent DaemonSet runs; an
       install with its own Datadog agent sets it in config. */ -}}
{{- if .root.Values.datadog.daemonset.enabled }}{{ $keys = append $keys "DD_AGENT_HOST" }}{{ end -}}
{{- range $role, $prefix := (include "polytomic.executorPrefixes" . | fromYaml) -}}
{{- range $sfx := (list "CPU" "MEMORY_RESERVATION" "MEMORY_MAXIMUM" "MEMORY_MEGA" "EPHEMERAL_STORAGE_REQUEST" "EPHEMERAL_STORAGE_MAXIMUM" "DATABASE_POOL_SIZE" "REDIS_POOL_SIZE" "CLEANUP_DELAY_SECONDS") -}}
{{- $keys = append $keys (printf "%s_%s" $prefix $sfx) -}}
{{- end -}}
{{- $keys = append $keys (ternary "TASK_EXECUTOR_TAGS" (printf "%s_TASK_EXECUTOR_TAGS" (upper $role)) (eq $role "task")) -}}
{{- end -}}
{{- join " " $keys -}}
{{- end }}

{{/*
Cross-field validation the JSON schema can't express.
*/}}
{{- define "polytomic.validateConfig" -}}
{{- $v := .root.Values -}}
{{- if not $v.image.tag }}{{ fail "image.tag is required" }}{{ end -}}
{{- if not $v.auth.url }}{{ fail "auth.url is required" }}{{ end -}}
{{- if not $v.polytomicDeploymentId }}{{ fail "polytomicDeploymentId is required" }}{{ end -}}
{{- if not $v.operationalBucket.name }}{{ fail "operationalBucket.name is required" }}{{ end -}}
{{- if not (has $v.operationalBucket.provider (list "s3" "gcs")) }}{{ fail (printf "operationalBucket.provider must be s3 or gcs (got %q)" $v.operationalBucket.provider) }}{{ end -}}
{{- if and (eq $v.operationalBucket.provider "s3") (not $v.operationalBucket.region) }}{{ fail "operationalBucket.region is required when operationalBucket.provider is s3" }}{{ end -}}
{{- $sources := splitList " " (include "polytomic.secretSourceNames" .) -}}
{{- if not $v.postgresql.enabled }}
  {{- if not $v.database.host }}{{ fail "database.host is required when postgresql.enabled is false" }}{{ end -}}
  {{- if not $v.database.port }}{{ fail "database.port is required" }}{{ end -}}
  {{- if not $v.database.username }}{{ fail "database.username is required" }}{{ end -}}
  {{- if not $v.database.polytomicDatabase }}{{ fail "database.polytomicDatabase is required" }}{{ end -}}
{{- else }}
  {{- $es := $v.postgresql.auth.existingSecret -}}
  {{- if not $es }}{{ fail "postgresql.auth.existingSecret is required when postgresql.enabled: name the Secret holding DATABASE_PASSWORD" }}{{ end -}}
  {{- if not (has $es $sources) }}{{ fail (printf "postgresql.auth.existingSecret %q must also be listed in secrets.existing or secrets.external.entries" $es) }}{{ end -}}
  {{- if ne $v.postgresql.auth.secretKeys.userPasswordKey "DATABASE_PASSWORD" }}{{ fail "postgresql.auth.secretKeys.userPasswordKey must be DATABASE_PASSWORD" }}{{ end -}}
  {{- if ne $v.postgresql.auth.secretKeys.adminPasswordKey "DATABASE_PASSWORD" }}{{ fail "postgresql.auth.secretKeys.adminPasswordKey must be DATABASE_PASSWORD" }}{{ end -}}
{{- end -}}
{{- if not $v.redis.enabled }}
  {{- if not $v.externalRedis.host }}{{ fail "externalRedis.host is required when redis.enabled is false" }}{{ end -}}
  {{- if not $v.externalRedis.port }}{{ fail "externalRedis.port is required" }}{{ end -}}
{{- else }}
  {{- $es := $v.redis.auth.existingSecret -}}
  {{- if not $es }}{{ fail "redis.auth.existingSecret is required when redis.enabled: name the Secret holding REDIS_PASSWORD" }}{{ end -}}
  {{- if not (has $es $sources) }}{{ fail (printf "redis.auth.existingSecret %q must also be listed in secrets.existing or secrets.external.entries" $es) }}{{ end -}}
  {{- if ne $v.redis.auth.existingSecretPasswordKey "REDIS_PASSWORD" }}{{ fail "redis.auth.existingSecretPasswordKey must be REDIS_PASSWORD" }}{{ end -}}
{{- end -}}
{{- $mode := $v.sharedVolume.mode | default "" -}}
{{- if not (has $mode (list "static" "dynamic" "emptyDir")) }}{{ fail (printf "sharedVolume.mode must be static, dynamic or emptyDir (got %q)" $mode) }}{{ end -}}
{{- if and (eq $mode "static") (not $v.sharedVolume.static.volumeHandle) }}{{ fail "sharedVolume.static.volumeHandle is required when sharedVolume.mode is static" }}{{ end -}}
{{- if and (eq $mode "static") (not $v.sharedVolume.static.driver) }}{{ fail "sharedVolume.static.driver is required when sharedVolume.mode is static" }}{{ end -}}
{{- end }}

{{/*
Chart-computed env vars appended to the app ConfigMap.
*/}}
{{- define "polytomic.extraConfigData" -}}
{{- include "polytomic.validateConfig" . -}}
{{- $v := .root.Values -}}
DATABASE_URL: {{ include "polytomic.databaseUrl" . | quote }}
REDIS_URL: {{ include "polytomic.redisUrl" . | quote }}
CACHE_URL: {{ include "polytomic.redisUrl" . | quote }}
KUBERNETES: "true"
KUBERNETES_NAMESPACE: {{ .root.Release.Namespace | quote }}
KUBERNETES_IMAGE: {{ include "polytomic-base.image" (dict "registry" $v.image.registry "image" $v.image.name "tag" $v.image.tag) }}
{{- with include "polytomic.runnerImagePullSecret" . }}
KUBERNETES_IMAGE_PULL_SECRET: {{ . | quote }}
{{- end }}
KUBERNETES_CONFIGMAP: {{ include "polytomic-base.configmapName" . }}
KUBERNETES_SECRET: {{ include "polytomic-base.secretName" . }}
KUBERNETES_SERVICE_ACCOUNT: {{ include "polytomic-base.serviceAccountName" . | quote }}
{{- if include "polytomic.sharedVolumeIsPvc" . }}
KUBERNETES_VOLUME: {{ $v.sharedVolume.persistentVolumeClaim.name | quote }}
{{- end }}
KUBERNETES_MOUNT_PATH: {{ $v.sharedVolume.mountPath | quote }}
POLYTOMIC_URL: {{ $v.auth.url | quote }}
APP_URL: {{ $v.auth.url | quote }}
DEPLOYMENT: {{ $v.polytomicDeploymentId | quote }}
LOCAL_DATA: {{ ternary "true" "false" (eq (include "polytomic.sharedVolumeIsPvc" .) "true") | quote }}
LOCAL_DATA_PATH: {{ $v.sharedVolume.mountPath | quote }}
DEFAULT_OPERATIONAL_BUCKET: {{ include "polytomic.operationalBucketUrl" . | quote }}
RECORD_LOG_BUCKET: {{ include "polytomic.bucketName" . | quote }}
EXECUTION_LOG_BUCKET: {{ include "polytomic.bucketName" . | quote }}
{{- if include "polytomic.bucketIsGcs" . }}
RECORD_LOG_REGION: "gcs"
EXECUTION_LOG_REGION: "gcs"
POLYTOMIC_USE_GCS: "true"
{{- else }}
RECORD_LOG_REGION: {{ $v.operationalBucket.region | quote }}
EXECUTION_LOG_REGION: {{ $v.operationalBucket.region | quote }}
AWS_REGION: {{ $v.operationalBucket.region | quote }}
{{- end }}
{{- if or $v.vector.daemonset.enabled $v.embeddedVector.enabled }}
EXECUTION_LOGS_V2: "true"
{{- end }}
{{- if $v.embeddedVector.enabled }}
INTERNAL_EXECUTION_LOGS: "true"
{{- end }}
{{- if $v.vector.daemonset.enabled }}
VECTOR_DAEMONSET: "true"
{{- end }}
{{- if and $v.vector.managedLogs (or $v.vector.daemonset.enabled $v.embeddedVector.enabled) }}
SEND_LOGS: "true"
{{- end }}
{{- if $v.datadog.daemonset.enabled }}
DD_AGENT_HOST: {{ include "polytomic-base.fullname" . }}-datadog
{{- end }}
{{- $primary := include "polytomic-base.secretName" . -}}
{{- $extraSecretNames := list -}}
{{- range $v.secrets.external.entries -}}
  {{- if ne .name $primary }}{{ $extraSecretNames = append $extraSecretNames .name }}{{ end -}}
{{- end -}}
{{- range $v.secrets.existing -}}
  {{- if ne .name $primary }}{{ $extraSecretNames = append $extraSecretNames .name }}{{ end -}}
{{- end -}}
{{- if $extraSecretNames }}
KUBERNETES_EXTRA_SECRETS: {{ join "," $extraSecretNames | quote }}
{{- end }}
{{- include "polytomic.runnerConfigData" . }}
{{- end }}

{{/*
NetworkPolicy egress for the bundled subcharts, matched by their Bitnami
instance labels.
*/}}
{{- define "polytomic.extraEgress" -}}
{{- $v := .root.Values -}}
{{- if $v.postgresql.enabled }}
- to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
          app.kubernetes.io/instance: {{ .root.Release.Name }}
  ports:
    - protocol: TCP
      port: 5432
{{- end }}
{{- if $v.redis.enabled }}
- to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: redis
          app.kubernetes.io/instance: {{ .root.Release.Name }}
  ports:
    - protocol: TCP
      port: 6379
{{- end }}
{{- end }}

{{/* ---------------------------------------------------------------------
MCP component: consumer helpers dispatched by polytomic-base as polytomic.mcp.*
--------------------------------------------------------------------- */}}

{{- define "polytomic.mcp.reservedConfigKeys" -}}
POLYTOMIC_BASE_URL POLYTOMIC_API_VERSION POLYTOMIC_HTTP_HOST POLYTOMIC_HTTP_PORT POLYTOMIC_AUTH_SERVER_URL POLYTOMIC_MCP_PUBLIC_ORIGIN POLYTOMIC_APPROVAL_SECRET MODEM_PUBLIC_KEY
{{- end }}

{{/*
In-cluster URL of the app Service, for MCP's default base URL.
*/}}
{{- define "polytomic.appServiceUrl" -}}
{{- $app := .root.Values.services.app -}}
{{- printf "http://%s-app:%v" (include "polytomic-base.fullname" (dict "root" .root "values" .root.Values "name" "")) $app.service.port -}}
{{- end }}

{{- define "polytomic.mcp.extraConfigData" -}}
{{- $m := .root.Values.mcp -}}
{{- if not $m.polytomic.apiVersion }}{{ fail "mcp.polytomic.apiVersion is required" }}{{ end -}}
{{- if not .root.Values.auth.url }}{{ fail "auth.url is required" }}{{ end -}}
POLYTOMIC_BASE_URL: {{ $m.polytomic.baseUrl | default (include "polytomic.appServiceUrl" .) | quote }}
POLYTOMIC_API_VERSION: {{ $m.polytomic.apiVersion | quote }}
POLYTOMIC_HTTP_HOST: "0.0.0.0"
POLYTOMIC_HTTP_PORT: {{ $m.services.http.service.targetPort | quote }}
POLYTOMIC_AUTH_SERVER_URL: {{ $m.polytomic.authServerUrl | default .root.Values.auth.url | quote }}
{{- with $m.polytomic.publicOrigin }}
POLYTOMIC_MCP_PUBLIC_ORIGIN: {{ . | quote }}
{{- end }}
{{- end }}

{{- define "polytomic.mcp.extraEgress" -}}
{{- end }}

{{/* ---------------------------------------------------------------------
Observability
--------------------------------------------------------------------- */}}

{{- define "polytomic.vectorImage" -}}
{{- include "polytomic-base.componentImage" (dict "block" .root.Values.vector.daemonset.image "default" .root.Values.image) -}}
{{- end }}

{{- define "polytomic.datadogImage" -}}
{{- include "polytomic-base.componentImage" (dict "block" .root.Values.datadog.daemonset.image "default" .root.Values.image) -}}
{{- end }}

{{/*
Vector DaemonSet ServiceAccount name. When create is false an explicit name
is required.
*/}}
{{- define "polytomic.vectorServiceAccountName" -}}
{{- $sa := .root.Values.vector.daemonset.serviceAccount -}}
{{- if $sa.create -}}
{{- default (printf "%s-vector" (include "polytomic-base.fullname" .)) $sa.name -}}
{{- else -}}
{{- required "vector.daemonset.serviceAccount.name is required when serviceAccount.create is false" $sa.name -}}
{{- end -}}
{{- end }}
