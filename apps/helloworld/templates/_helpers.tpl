{{/* Create chart name and version to be used by the chart label */}}
{{- define "devops-stack-helloworld.chart" }}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{ end -}}

{{/* Define selectors to be used (to be also used as templates) */}}
{{- define "devops-stack-helloworld.selector" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{ end -}}

{{/* Define common labels */}}
{{- define "devops-stack-helloworld.labels" -}}
{{ include "devops-stack-helloworld.selector" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{ end -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "devops-stack-helloworld.chart" . }}
{{- end -}}
{{/* End labels */}}
