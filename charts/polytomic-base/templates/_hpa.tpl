{{- define "polytomic-base.hpa" -}}
{{- $ctx := . -}}
{{- range $serviceName, $serviceConfig := .values.services }}
{{- if and (ne $serviceName "defaults") (kindIs "map" $serviceConfig) $serviceConfig.enabled $serviceConfig.autoscaling $serviceConfig.autoscaling.enabled }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "polytomic-base.fullname" $ctx }}-{{ $serviceName }}
  namespace: {{ $ctx.root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" $ctx | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "polytomic-base.fullname" $ctx }}-{{ $serviceName }}
  minReplicas: {{ $serviceConfig.autoscaling.minReplicas }}
  maxReplicas: {{ $serviceConfig.autoscaling.maxReplicas }}
  metrics:
    {{- if $serviceConfig.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $serviceConfig.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $serviceConfig.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $serviceConfig.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
  {{- with $serviceConfig.autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
