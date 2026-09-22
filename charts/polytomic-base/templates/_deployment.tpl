{{/*
Renders one Deployment per enabled service in .values.services (excluding
the "defaults" key, which holds shared per-pod settings).

initContainers, volumes and volumeMounts are rendered through `tpl` with
the context dict, so values can embed {{ include "polytomic-base.X" . }}
expressions and reach the Helm root as .root (trusted-input territory).

image accessor: per-service overrides on .image.{registry,name,tag},
each falling back to .values.image.<field>.
*/}}
{{- define "polytomic-base.deployment" -}}
{{- $ctx := . -}}
{{- range $serviceName, $serviceConfig := .values.services }}
{{- if and (ne $serviceName "defaults") (kindIs "map" $serviceConfig) (hasKey $serviceConfig "enabled") $serviceConfig.enabled }}
{{- $configChecksum := include "polytomic-base.configmapData" $ctx | sha256sum }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "polytomic-base.fullname" $ctx }}-{{ $serviceName }}
  namespace: {{ $ctx.root.Release.Namespace }}
  labels:
    {{- include "polytomic-base.labels" $ctx | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
spec:
  revisionHistoryLimit: {{ $ctx.values.revisionHistoryLimit | default 10 }}
  {{- if not (and $serviceConfig.autoscaling $serviceConfig.autoscaling.enabled) }}
  replicas: {{ $serviceConfig.replicas }}
  {{- end }}
  {{- with $serviceConfig.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if $serviceConfig.minReadySeconds }}
  minReadySeconds: {{ $serviceConfig.minReadySeconds }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "polytomic-base.selectorLabels" $ctx | nindent 6 }}
      app.kubernetes.io/component: {{ $serviceName }}
  template:
    metadata:
      annotations:
        checksum/config: {{ $configChecksum }}
        {{- if and $serviceConfig.metrics $serviceConfig.metrics.enabled }}
        prometheus.io/scrape: "true"
        prometheus.io/path: {{ $serviceConfig.metrics.path | default "/metrics" }}
        prometheus.io/port: {{ $serviceConfig.metrics.port | default "8080" | quote }}
        {{- end }}
        {{- with $ctx.values.services.defaults.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with $serviceConfig.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "polytomic-base.selectorLabels" $ctx | nindent 8 }}
        app.kubernetes.io/component: {{ $serviceName }}
        {{- with $ctx.values.services.defaults.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with $serviceConfig.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with $ctx.values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "polytomic-base.serviceAccountName" $ctx }}
      securityContext:
        {{- toYaml ($serviceConfig.podSecurityContext | default $ctx.values.podSecurityContext) | nindent 8 }}
      {{- if $serviceConfig.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ $serviceConfig.terminationGracePeriodSeconds }}
      {{- end }}
      {{- if $serviceConfig.priorityClassName }}
      priorityClassName: {{ $serviceConfig.priorityClassName }}
      {{- end }}
      {{- $initContainers := include "polytomic-base.serviceList" (dict "ctx" $ctx "svc" $serviceConfig "key" "initContainers") }}
      {{- if $initContainers }}
      initContainers:
        {{- tpl $initContainers $ctx | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ $serviceName }}
          securityContext:
            {{- toYaml ($serviceConfig.securityContext | default $ctx.values.securityContext) | nindent 12 }}
          image: {{ include "polytomic-base.image" (dict "registry" (($serviceConfig.image).registry | default $ctx.values.image.registry) "image" (($serviceConfig.image).name | default $ctx.values.image.name) "tag" (($serviceConfig.image).tag | default $ctx.values.image.tag)) }}
          imagePullPolicy: {{ $ctx.values.image.pullPolicy }}
          {{- if $serviceConfig.service }}
          ports:
            - name: http
              containerPort: {{ $serviceConfig.service.targetPort }}
              protocol: TCP
          {{- end }}
          {{- if or $serviceConfig.env $serviceConfig.extraEnv }}
          env:
            {{- range $key, $value := $serviceConfig.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- with $serviceConfig.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "polytomic-base.configmapName" $ctx }}
            {{- range $ctx.values.secrets.external.entries }}
            - secretRef:
                name: {{ .name }}
            {{- end }}
            {{- range $ctx.values.secrets.existing }}
            - secretRef:
                name: {{ .name }}
            {{- end }}
            {{- with $serviceConfig.extraEnvFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- with $serviceConfig.lifecycle }}
          lifecycle:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if and $serviceConfig.healthCheck $serviceConfig.healthCheck.enabled }}
          livenessProbe:
            httpGet:
              path: {{ $serviceConfig.healthCheck.path }}
              port: http
            initialDelaySeconds: {{ $ctx.values.healthProbes.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ $ctx.values.healthProbes.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ $ctx.values.healthProbes.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ $ctx.values.healthProbes.livenessProbe.failureThreshold }}
          readinessProbe:
            httpGet:
              path: {{ $serviceConfig.healthCheck.path }}
              port: http
            initialDelaySeconds: {{ $ctx.values.healthProbes.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ $ctx.values.healthProbes.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ $ctx.values.healthProbes.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ $ctx.values.healthProbes.readinessProbe.failureThreshold }}
          {{- if and $ctx.values.healthProbes.startupProbe $ctx.values.healthProbes.startupProbe.enabled }}
          startupProbe:
            httpGet:
              path: {{ $serviceConfig.healthCheck.path }}
              port: http
            periodSeconds: {{ $ctx.values.healthProbes.startupProbe.periodSeconds }}
            timeoutSeconds: {{ $ctx.values.healthProbes.startupProbe.timeoutSeconds }}
            failureThreshold: {{ $ctx.values.healthProbes.startupProbe.failureThreshold }}
          {{- end }}
          {{- end }}
          resources:
            {{- toYaml $serviceConfig.resources | nindent 12 }}
          {{- $volumeMounts := include "polytomic-base.serviceList" (dict "ctx" $ctx "svc" $serviceConfig "key" "volumeMounts") }}
          {{- if $volumeMounts }}
          volumeMounts:
            {{- tpl $volumeMounts $ctx | nindent 12 }}
          {{- end }}
        {{- with $serviceConfig.sidecarContainers }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- $volumes := include "polytomic-base.serviceList" (dict "ctx" $ctx "svc" $serviceConfig "key" "volumes") }}
      {{- if $volumes }}
      volumes:
        {{- tpl $volumes $ctx | nindent 8 }}
      {{- end }}
      {{- with $serviceConfig.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- $nodeSelector := include "polytomic-base.serviceDefault" (dict "ctx" $ctx "svc" $serviceConfig "key" "nodeSelector") }}
      {{- if $nodeSelector }}
      nodeSelector:
        {{- $nodeSelector | nindent 8 }}
      {{- end }}
      {{- $affinity := include "polytomic-base.serviceDefault" (dict "ctx" $ctx "svc" $serviceConfig "key" "affinity") }}
      {{- if $affinity }}
      affinity:
        {{- $affinity | nindent 8 }}
      {{- end }}
      {{- $tolerations := include "polytomic-base.serviceDefault" (dict "ctx" $ctx "svc" $serviceConfig "key" "tolerations") }}
      {{- if $tolerations }}
      tolerations:
        {{- $tolerations | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}
{{- end }}
