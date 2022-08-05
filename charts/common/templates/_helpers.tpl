{{/*
Expand the name of the chart.
*/}}
{{- define "helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helm.fullname" -}}
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
{{- define "helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ejlevin1.generic.labels" -}}
labels:
  helm.sh/chart: {{ include "helm.chart" (dict "Chart" .root.Chart) }}
  app.kubernetes.io/name: {{ required ".name is required" .Values.name }}
  app.kubernetes.io/instance: {{ .root.Release.Name }}
  app.kubernetes.io/version: {{ default .root.Chart.Version .root.Chart.AppVersion | quote }}
  app.kubernetes.io/managed-by: {{ .root.Release.Service }}
  {{- with .Values.labels }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}

{{- define "helm.labels" -}}
helm.sh/chart: {{ include "helm.chart" . }}
{{ include "helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ejlevin1.failAndPrintKeys" -}}
{{- fail (print "Keys [" (keys .) "]") }}
{{- end }}

{{- define "ejlevin1.failAndPrintValue" -}}
{{- fail (print "Value [" . "]") }}
{{- end }}

{{- define "ejlevin1.labels" -}}
{{- if .labels }}
{{- with .labels }}
labels: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.helm-labels" -}}
labels:
  {{- include "helm.labels" ( .Root | default $ ) | nindent 2 }}
  {{- with ( (.Values).labels | default .labels ) }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}

{{- define "ejlevin1.generic.annotations" -}}
{{- with .Values.annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- define "ejlevin1.annotations" -}}
{{- with ( (.Values).annotations | default .annotations ) }}
annotations: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*env variable template*/}}
{{- define "helm.printEnvVariables" -}}
{{- if . -}}
env: 
    {{- include "helm.toNameValueList" . | indent 2 }}
{{- end }}
{{- end }}


{{- define "helm.toNameValueList" -}}
    {{- if kindIs "slice" . }}
        {{- range $item := . }}
            {{- if kindIs "map" $item }}
                {{- if $item.name  }}
                    {{- (print "- name: " $item.name) | nindent 0 }}
                    {{- include "helm.toItemValue" $item | indent 2 }}
                {{- else }}
                    {{ fail (print "envVariable [" $item "] must have a .name defined.") }}
                {{- end }}
            {{- else if kindIs "string" $item }}
                    {{- (print "- name: " (splitList "=" $item | mustFirst)) | nindent 0 }}
                    {{- (print "  value: " (splitList "=" $item | mustRest | join "=" | quote)) | nindent 0 }}
            {{- else }}
                {{ fail (list "Unknown env variable type [" (kindOf $item) "]" | join "") }}
            {{- end }}
        {{- end }}
    {{- else if kindIs "map"  . }}
        {{- range $key, $value := . }}
            {{- (print "- name: " $key) | nindent 0 }}
            {{- include "helm.toItemValue" $value | indent 2 }}
        {{- end }}
    {{- end }}
{{- end }}

{{- define "helm.toItemValue" -}}
    {{- if kindIs "map" . }}
        {{- if hasKey . "value" }}
            {{- (print "value: " (.value | quote)) | nindent 0 }}
        {{- else if hasKey . "valueFrom" }}
            {{- print "valueFrom: " (toYaml .valueFrom | nindent 2) | nindent 0 }}
        {{- else }}
            {{ fail (print "envVariable [" . "] must have a .value or .valueFrom defined.") }}
        {{- end }}
    {{- else }}
        {{- (print "value: " (. | quote)) | nindent 0 }}
    {{- end }}
{{- end }}

{{- define "helm.toProbe" }}
{{- if .tcpSocket }}
tcpSocket:
  port: {{ .tcpSocket.port }}
{{- else if .httpGet }}
httpGet:
  path: {{ .httpGet.path }}
  port: {{ .httpGet.port }}
{{- else if .exec }}
exec: {{ toYaml .exec | nindent 2 }}
{{- else }}
    {{ fail "probe definition must have either a tcpSocket, httpGet, or exec defined." }}
{{- end }}
failureThreshold: {{ .failureThreshold }}
periodSeconds: {{ .periodSeconds }}
{{- if .initialDelaySeconds }}
initialDelaySeconds: {{ .initialDelaySeconds }}
{{- end }}
{{- if .timeoutSeconds }}
timeoutSeconds: {{ .timeoutSeconds }}
{{- end }}
{{- if .successThreshold }}
successThreshold: {{ .successThreshold }}
{{- end }}
{{- end }}

{{- define "helm.toVolumeMount" }}
{{- range . }}
- name: {{ required ".name is required to define a volume mount." .name | quote }}
  mountPath: {{ required ".mountPath is required to define a volume mount." .mountPath | quote }}
  {{- if .subPath }}
  subPath: {{ .subPath }}
  {{- end }}
  {{- if .readOnly }}
  readOnly: {{ .readOnly | default true }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerBase" }}
{{- if .securityContext }}
securityContext:
  {{- toYaml .securityContext | nindent 2 }}
{{- end }}
image: {{ include "common.images.image" ( dict "imageRoot" .image "global" . ) }}
imagePullPolicy: {{ .image.pullPolicy | default "Always" }}
{{- if (.command).binaryName }}
command: [{{ .command.binaryName | quote }}]
{{- end }}
args:
{{- range .command.args }}
  - {{ . | quote }}
{{- end }}
{{- if (.service).port }}
ports:
{{- range .service.port }}
  - name: {{ .name }}
    containerPort: {{ .containerPort }}
{{- end }}
{{- end }}
{{- if .resources }}
resources: {{- toYaml .resources | nindent 2 }}
{{- end }}
{{- if .envVariables }}
env: 
  {{- include "helm.toNameValueList" .envVariables | indent 2 }}
{{- end }}
{{- if or .envVariablesFromSecrets .envVariablesFromConfigMaps }}
envFrom:
{{- if .envVariablesFromSecrets }}
{{- range $key, $value := .envVariablesFromSecrets }}
  - name: {{ $key | quote }}
    valueFrom:
      secretKeyRef:
        name: {{ $value.name }}
        key: {{ $value.key }}
{{- end -}}
{{- end -}}
{{- if .envVariablesFromConfigMaps }}
{{- range $key, $value := .envVariablesFromConfigMaps }}
  - name: {{ $key | quote }}
    valueFrom:
      configMapKeyRef:
        name: {{ $value.name }}
        key: {{ $value.key }}
{{- end -}}
{{- end -}}
{{- end }}
{{- include "ejlevin1.containerVolumeMounts" . }}
{{- end }}

{{- define "ejlevin1.containerProbes" }}
{{- if (.startupProbe).enabled }}
startupProbe:
  {{- include "helm.toProbe" .startupProbe | indent 2 }}
{{- end }}
{{- if (.livenessProbe).enabled }}
livenessProbe:
  {{- include "helm.toProbe" .livenessProbe | indent 2 }}
{{- end }}
{{- if (.readinessProbe).enabled }}
readinessProbe:
  {{- include "helm.toProbe" .readinessProbe | indent 2 }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerLifecycle" }}
{{- if .commandsAfterPodStart }}
lifecycle:
  postStart:
    exec:
      command:
      {{-  range .commandsAfterPodStart.args }}
      - {{ . | quote }}
      {{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerVolumeMounts" }}
{{- if or .secretVolumes .persistentVolumes .emptyDirVolumes .configMapVolumes }}
volumeMounts:
{{- if .secretVolumes }}
  {{- include "helm.toVolumeMount" .secretVolumes | indent 2 }}
{{- end }}
{{- if .persistentVolumes }}
  {{- include "helm.toVolumeMount" .persistentVolumes | indent 2 }}
{{- end }}
{{- if .emptyDirVolumes }}
  {{- include "helm.toVolumeMount" .emptyDirVolumes | indent 2 }}
{{- end }}
{{- if .configMapVolumes }}
  {{- include "helm.toVolumeMount" .configMapVolumes | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.pod.volumeMounts" }}
{{- if or .secretVolumes .persistentVolumes .emptyDirVolumes .configMapVolumes (.sidecar).configMapVolumes (.sidecar).secretVolumes }}
volumes:
{{- if .secretVolumes }}
{{- range .secretVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  secret:
    secretName: {{ .secretName }}
    {{- if .defaultMode }}
    defaultMode: {{ .defaultMode }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if .persistentVolumes }}
{{- range .persistentVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  persistentVolumeClaim:
    claimName: {{ .claimName | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- if .emptyDirVolumes }}
{{- range .emptyDirVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  emptyDir: {}
{{- end }}
{{- end }}
{{- end }}
{{- if .configMapVolumes }}
{{- range .configMapVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  configMap:
    name: {{ default .name .configMapName | quote }}
    {{- if .defaultMode }}
    defaultMode: {{ .defaultMode }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if (.sidecar).configMapVolumes }}
{{- range .sidecar.configMapVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  configMap:
    name: {{ default .name .configMapName | quote }}
    {{- if .defaultMode }}
    defaultMode: {{ .defaultMode }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if (.sidecar).secretVolumes }}
{{- range .sidecar.secretVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  secret:
    secretName: {{ .secretName }}
    {{- if .defaultMode }}
    defaultMode: {{ .defaultMode }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}