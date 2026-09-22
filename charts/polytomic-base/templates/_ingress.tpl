{{/*
Ingress backend defaults to the "app" service when a host's paths[].service
is unset, falling back to the alphabetically-first enabled service that has
a .service block. Port defaults to that service's .service.port. Supports
both the nested tls.hosts shape and the flat tls list.
*/}}
{{- define "polytomic-base.ingress" -}}
{{- if .values.ingress.enabled -}}
{{- $ctx := . -}}
{{- $fullName := include "polytomic-base.fullname" . -}}
{{- $defaultBackend := "" -}}
{{- $appSvc := index .values.services "app" -}}
{{- if and $appSvc (kindIs "map" $appSvc) $appSvc.enabled $appSvc.service }}
{{- $defaultBackend = "app" }}
{{- end }}
{{- if not $defaultBackend }}
{{- range $name, $svc := .values.services }}
{{- if and (ne $name "defaults") (kindIs "map" $svc) $svc.enabled $svc.service (not $defaultBackend) }}
{{- $defaultBackend = $name }}
{{- end }}
{{- end }}
{{- end }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" . | nindent 4 }}
    app.kubernetes.io/component: ingress
  {{- with .values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .values.ingress.className }}
  ingressClassName: {{ .values.ingress.className }}
  {{- end }}
  {{- if .values.ingress.tls }}
  tls:
    {{- range .values.ingress.tls }}
    {{- if .hosts }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- else }}
    - {{ toYaml . | nindent 6 | trim }}
    {{- end }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .values.ingress.hosts }}
    - {{- if .host }}
      host: {{ .host | quote }}
      {{- end }}
      http:
        paths:
          {{- range .paths }}
          {{- $svcName := .service | default $defaultBackend }}
          {{- $svcPort := .port }}
          {{- if not $svcPort }}
          {{- $svcPort = (index $ctx.values.services $svcName).service.port }}
          {{- end }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $fullName }}-{{ $svcName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
