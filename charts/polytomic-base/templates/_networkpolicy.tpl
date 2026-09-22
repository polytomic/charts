{{/*
NetworkPolicy: ingress rules permit every enabled service that has a
.service block on its own port. Egress is DNS, same-namespace pods, the
freeform networkPolicy.egress list, then whatever the consumer's
"<consumer>.extraEgress" helper returns (a YAML list of egress rules).
*/}}
{{- define "polytomic-base.networkpolicy" -}}
{{- if .values.networkPolicy.enabled }}
{{- $ports := list }}
{{- range $name, $svc := .values.services }}
{{- if and (ne $name "defaults") (kindIs "map" $svc) $svc.enabled $svc.service }}
{{- $ports = append $ports $svc.service.port }}
{{- end }}
{{- end }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "polytomic-base.fullname" . }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "polytomic-base.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    {{- if .values.networkPolicy.ingressNamespaceSelector }}
    - from:
        - namespaceSelector:
            matchLabels:
              {{- toYaml .values.networkPolicy.ingressNamespaceSelector | nindent 14 }}
      ports:
        {{- range $ports }}
        - protocol: TCP
          port: {{ . }}
        {{- end }}
    {{- end }}
    {{- range .values.networkPolicy.ingressCidrs }}
    - from:
        - ipBlock:
            cidr: {{ . }}
      ports:
        {{- range $ports }}
        - protocol: TCP
          port: {{ . }}
        {{- end }}
    {{- end }}
    - from:
        - podSelector: {}
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - podSelector: {}
    {{- range .values.networkPolicy.egress }}
    - {{ toYaml . | nindent 6 | trim }}
    {{- end }}
    {{- $extra := include (printf "%s.extraEgress" (include "polytomic-base.consumer" .)) . | trim }}
    {{- if $extra }}
    {{- $extra | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
