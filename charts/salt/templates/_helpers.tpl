{{/* Expand the name of the chart. */}}
{{- define "salt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, capped at 63 chars for the label limit. StatefulSet
pod names append an ordinal, so leave room for it.
*/}}
{{- define "salt.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "salt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "salt.labels" -}}
helm.sh/chart: {{ include "salt.chart" . }}
{{ include "salt.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: master
{{- end -}}

{{- define "salt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "salt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "salt.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "salt.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* The image reference, falling back to the chart's appVersion. */}}
{{- define "salt.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{/*
The mounts Salt needs to write to when the root filesystem is read-only.
Shared by the master and api containers so the two cannot drift apart.
*/}}
{{- define "salt.writableMounts" -}}
- name: run
  mountPath: /var/run/salt
- name: logs
  mountPath: /var/log/salt
- name: cache
  mountPath: /var/cache/salt
- name: tmp
  mountPath: /tmp
{{- end -}}
