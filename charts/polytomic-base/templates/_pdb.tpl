{{- define "polytomic-base.pdb" -}}
{{- $ctx := . -}}
{{- range $serviceName, $serviceConfig := .values.services }}
{{- if and (ne $serviceName "defaults") (kindIs "map" $serviceConfig) (hasKey $serviceConfig "enabled") $serviceConfig.enabled $serviceConfig.podDisruptionBudget $serviceConfig.podDisruptionBudget.enabled }}
{{- $pdb := $serviceConfig.podDisruptionBudget }}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "polytomic-base.fullname" $ctx }}-{{ $serviceName }}
  namespace: {{ $ctx.root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" $ctx | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
spec:
  {{- if $pdb.minAvailable }}
  minAvailable: {{ $pdb.minAvailable }}
  {{- else if $pdb.maxUnavailable }}
  maxUnavailable: {{ $pdb.maxUnavailable }}
  {{- else }}
  minAvailable: 1
  {{- end }}
  selector:
    matchLabels:
      {{- include "polytomic-base.selectorLabels" $ctx | nindent 6 }}
      app.kubernetes.io/component: {{ $serviceName }}
{{- end }}
{{- end }}
{{- end }}
