{{- define "test-consumer.reservedConfigKeys" -}}
PORT PRIMARY_SECRET
{{- end }}

{{- define "test-consumer.extraConfigData" -}}
PORT: {{ .values.services.http.service.targetPort | quote }}
PRIMARY_SECRET: {{ include "polytomic-base.secretName" . | quote }}
{{- end }}

{{- define "test-consumer.extraEgress" -}}
{{- with .values.extraEgress }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Sidecar component helpers, dispatched as test-consumer.sidecar.*. The
resolved image is written to the ConfigMap so componentImage is observable.
*/}}
{{- define "test-consumer.sidecar.reservedConfigKeys" -}}
COMPONENT IMAGE
{{- end }}

{{- define "test-consumer.sidecar.extraConfigData" -}}
COMPONENT: {{ .name | quote }}
IMAGE: {{ include "polytomic-base.componentImage" (dict "block" .values.image "default" .root.Values.image) | quote }}
{{- end }}

{{- define "test-consumer.sidecar.extraEgress" -}}
{{- with .values.extraEgress }}
{{- toYaml . }}
{{- end }}
{{- end }}
