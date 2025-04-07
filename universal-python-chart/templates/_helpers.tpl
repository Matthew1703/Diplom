{{/*
Expand the name of the chart.
*/}}
{{- define "universal-python.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "universal-python.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "universal-python.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "universal-python.labels" -}}
helm.sh/chart: {{ include "universal-python.chart" . }}
{{ include "universal-python.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "universal-python.selectorLabels" -}}
app.kubernetes.io/name: {{ include "universal-python.name" . }}
app.kubernetes.io/instance: {{ .Values.application.instance }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "universal-python.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "universal-python.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Prehook annotations with weight -5
*/}}
{{- define "universal-python.prehook-5" -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-5"
helm.sh/hook-delete-policy: before-hook-creation,hook-failed
{{- end }}

{{/*
Prehook annotations with weight -10
*/}}
{{- define "universal-python.prehook-10" -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-10"
helm.sh/hook-delete-policy: before-hook-creation,hook-failed
{{- end }}

{{/*
Prehook annotations with weight -15
*/}}
{{- define "universal-python.prehook-15" -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-15"
helm.sh/hook-delete-policy: before-hook-creation,hook-failed
{{- end }}

{{/*
Annotations for pods
*/}}
{{- define "universal-python.podAnnotations" -}}
{{- with .Values.podAnnotations }}
{{- toYaml . }}
{{- end }}
checksum/config:
  {{- if .Values.customChecksum }}
    {{ .Values.customChecksum }}
  {{- else }}
    {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  {{- end }}
{{- end }}

{{/*
Annotations for deployment
*/}}
{{- define "universal-python.deploymentAnnotations" -}}
{{- with .Values.deploymentAnnotations }}
{{- toYaml . }}
{{- end }}
{{/*
Annotatioms for Stakater Reloader
*/}}
{{- if .Values.reloaderAnnotations.enabled }}
{{- if .Values.reloaderAnnotations.customannotations }}
{{- toYaml . }}
{{- else }}
reloader.stakater.com/auto: "true"
{{- end }}
{{- end }}
{{- end }}