{{- define "polytomic-base.serviceaccount" -}}
{{- if .values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "polytomic-base.serviceAccountName" . }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" . | nindent 4 }}
  {{- with .values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .values.serviceAccount.automount }}
{{- end }}
{{- end }}
