{{/*
Expand the name of the chart.
*/}}
{{- define "bank-of-anthos.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bank-of-anthos.fullname" -}}
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
{{- define "bank-of-anthos.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "bank-of-anthos.labels" -}}
helm.sh/chart: {{ include "bank-of-anthos.chart" . }}
{{ include "bank-of-anthos.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
application: {{ .Values.global.labels.application | default "bank-of-anthos" }}
{{- end }}

{{/*
Selector labels (stable identity for Services / Deployments).
*/}}
{{- define "bank-of-anthos.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bank-of-anthos.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name used by app pods.
*/}}
{{- define "bank-of-anthos.serviceAccountName" -}}
{{- default "bank-of-anthos" .Values.serviceAccount.name }}
{{- end }}

{{/*
Build a full container image reference: registry/repository:tag
Usage: include "bank-of-anthos.image" (dict "root" . "image" .Values.frontend.image)
*/}}
{{- define "bank-of-anthos.image" -}}
{{- $registry := .root.Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" $registry .image.repository .image.tag -}}
{{- end }}

{{/*
JWT Secret name (created by External Secrets — not by this chart).
*/}}
{{- define "bank-of-anthos.jwtSecretName" -}}
{{- .Values.secrets.jwt.name -}}
{{- end }}

{{/*
Accounts DB credentials Secret name.
*/}}
{{- define "bank-of-anthos.accountsDbSecretName" -}}
{{- .Values.secrets.accountsDb.name -}}
{{- end }}

{{/*
Ledger DB credentials Secret name.
*/}}
{{- define "bank-of-anthos.ledgerDbSecretName" -}}
{{- .Values.secrets.ledgerDb.name -}}
{{- end }}
