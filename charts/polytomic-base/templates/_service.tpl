{{- define "polytomic-base.service" -}}
{{- $ctx := . -}}
{{- range $serviceName, $serviceConfig := .values.services }}
{{- if and (ne $serviceName "defaults") (kindIs "map" $serviceConfig) $serviceConfig.enabled $serviceConfig.service }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "polytomic-base.fullname" $ctx }}-{{ $serviceName }}
  namespace: {{ $ctx.root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" $ctx | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
  {{- with $serviceConfig.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $serviceConfig.service.type }}
  {{- if and $serviceConfig.service.externalTrafficPolicy (or (eq $serviceConfig.service.type "NodePort") (eq $serviceConfig.service.type "LoadBalancer")) }}
  externalTrafficPolicy: {{ $serviceConfig.service.externalTrafficPolicy }}
  {{- end }}
  ports:
    - port: {{ $serviceConfig.service.port }}
      targetPort: {{ $serviceConfig.service.targetPort }}
      protocol: TCP
      name: http
      {{- if and (eq $serviceConfig.service.type "NodePort") $serviceConfig.service.nodePort }}
      nodePort: {{ $serviceConfig.service.nodePort }}
      {{- end }}
  selector:
    {{- include "polytomic-base.selectorLabels" $ctx | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
{{- end }}
{{- end }}
{{- end }}
