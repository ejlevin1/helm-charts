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
{{ $root := $ }}
{{- if .containerRoot.securityContext }}
securityContext:
  {{- toYaml .containerRoot.securityContext | nindent 2 }}
{{- end }}
image: {{ include "common.images.image" ( dict "imageRoot" .containerRoot.image "global" . ) }}
imagePullPolicy: {{ .containerRoot.image.pullPolicy | default "Always" }}
{{- include "ejlevin1.containerCommand" ( dict "Root" $root "commandRoot" .containerRoot.command ) }}
{{- if ((.containerRoot).service).port }}
ports:
{{- range .containerRoot.service.port }}
  - name: {{ .name }}
    containerPort: {{ .containerPort }}
{{- end }}
{{- end }}
{{- if .containerRoot.resources }}
resources: {{- toYaml .containerRoot.resources | nindent 2 }}
{{- end }}
env:
{{- if .containerRoot.envVariablesFromFields }}
{{- range $key, $value := .containerRoot.envVariablesFromFields }}
  - name: {{ $key | trim }}
    valueFrom:
      fieldRef:
        apiVersion: {{ default "v1" $value.version | trim }}
        fieldPath: {{ $value.path | trim }}
{{- end -}}
{{- end -}}
{{- if .containerRoot.envVariablesFromSecrets }}
{{- range $key, $value := .containerRoot.envVariablesFromSecrets }}
  - name: {{ $key | trim }}
    valueFrom:
      secretKeyRef:
        {{- toYaml $value | nindent 8 }}
{{- end -}}
{{- end -}}
{{- if .containerRoot.envVariablesFromConfigMaps }}
{{- range $key, $value := .containerRoot.envVariablesFromConfigMaps }}
  - name: {{ $key | trim }}
    valueFrom:
      configMapKeyRef:
        {{- toYaml $value | nindent 8 }}
{{- end -}}
{{- end }}
{{- if .containerRoot.envVariables }}
  {{- include "helm.toNameValueList" .containerRoot.envVariables | indent 2 }}
{{- end }}
{{- end }}


{{- define "ejlevin1.containerCommand" }}
{{- if .commandRoot }}
{{- if .commandRoot.binaryName }}
command: [{{ .commandRoot.binaryName | trim | quote }}]
{{- end }}
{{- if .commandRoot.args }}
args:
  {{- range .commandRoot.args }}
    {{- print "- " (print . | trim | quote) | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerProbes" }}
{{- if ((.containerRoot).startupProbe).enabled }}
startupProbe: {{- include "helm.toProbe" .containerRoot.startupProbe | nindent 2 }}
{{- end }}
{{- if ((.containerRoot).livenessProbe).enabled }}
livenessProbe: {{- include "helm.toProbe" .containerRoot.livenessProbe | nindent 2 }}
{{- end }}
{{- if ((.containerRoot).readinessProbe).enabled }}
readinessProbe: {{- include "helm.toProbe" .containerRoot.readinessProbe | nindent 2 }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerLifecycle" }}
{{- if .containerRoot.commandsAfterPodStart }}
lifecycle:
  postStart:
    exec:
      command:
      {{-  range .containerRoot.commandsAfterPodStart.args }}
      - {{ . | quote }}
      {{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.containerVolumeMounts" }}
{{- if or .containerRoot.secretVolumes .containerRoot.persistentVolumes .containerRoot.emptyDirVolumes .containerRoot.configMapVolumes }}
volumeMounts:
{{- if .containerRoot.secretVolumes }}
  {{- include "helm.toVolumeMount" .containerRoot.secretVolumes | nindent 2 }}
{{- end }}
{{- if .containerRoot.persistentVolumes }}
  {{- include "helm.toVolumeMount" .containerRoot.persistentVolumes | nindent 2 }}
{{- end }}
{{- if .containerRoot.emptyDirVolumes }}
  {{- include "helm.toVolumeMount" .containerRoot.emptyDirVolumes | nindent 2 }}
{{- end }}
{{- if .containerRoot.configMapVolumes }}
  {{- include "helm.toVolumeMount" .containerRoot.configMapVolumes | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ejlevin1.pod.volumeMounts" }}
{{- if or .containerRoot.secretVolumes .containerRoot.persistentVolumes .containerRoot.emptyDirVolumes .containerRoot.configMapVolumes ((.containerRoot).sidecar).configMapVolumes ((.containerRoot).sidecar).secretVolumes }}
volumes:
{{- if .containerRoot.secretVolumes }}
{{- range .containerRoot.secretVolumes }}
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
{{- if .containerRoot.hostPathVolumes }}
{{- range .containerRoot.hostPathVolumes }}
{{- if not .morethanonce }}
- name: {{ required ".name must be specified on hostPathVolumes" .name | quote }}
  hostPath:
    path: {{ required ".path must be specified on hostPathVolumes" .path | quote }}
    type: {{ default "DirectoryOrCreate" .type | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- if .containerRoot.persistentVolumes }}
{{- range .containerRoot.persistentVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  persistentVolumeClaim:
    {{- if .claimName }}
    claimName: {{ .claimName | quote }}
    {{- else if .existingClaimName }}
    claimName: {{ .existingClaimName | quote }}
    {{- else }}
    {{- fail "Must set either a claimName or existingClaimName on a persistentVolume" }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if .containerRoot.emptyDirVolumes }}
{{- range .containerRoot.emptyDirVolumes }}
{{- if not .morethanonce }}
- name: {{ .name | quote }}
  emptyDir: {}
{{- end }}
{{- end }}
{{- end }}
{{- if .containerRoot.configMapVolumes }}
{{- range .containerRoot.configMapVolumes }}
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
{{- if ((.containerRoot).sidecar).configMapVolumes }}
{{- range .containerRoot.sidecar.configMapVolumes }}
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
{{- if ((.containerRoot).sidecar).secretVolumes }}
{{- range .containerRoot.sidecar.secretVolumes }}
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