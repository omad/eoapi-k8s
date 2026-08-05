{{/*
PostgreSQL environment variables based on the configured type
*/}}
{{- define "eoapi.postgresqlEnv" -}}
{{- if eq .Values.postgresql.type "postgrescluster" }}
  {{- include "eoapi.postgresclusterSecrets" . }}
{{- else if eq .Values.postgresql.type "external-plaintext" }}
  {{- include "eoapi.externalPlaintextPgSecrets" . }}
{{- else if eq .Values.postgresql.type "external-secret" }}
  {{- include "eoapi.externalSecretPgSecrets" . }}
{{- end }}
{{- end }}

{{/*
Whether the pgstac superuser/admin bootstrap job (extensions + pgstac roles/grants)
should run. This requires elevated privileges and is separate from the regular
runtime credentials used by services and the migrate job.
- postgrescluster: always runs (uses the in-cluster `postgres` superuser)
- external-*: only runs when admin credentials are supplied
*/}}
{{- define "eoapi.pgstacSuperuserInitEnabled" -}}
{{- if .Values.pgstacBootstrap.enabled -}}
  {{- if .Values.postgrescluster.enabled -}}
true
  {{- else if or .Values.postgresql.external.admin.existingSecret.name .Values.postgresql.external.admin.credentials.username -}}
true
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
PostgreSQL environment variables for the superuser/admin bootstrap job.
Resolves elevated credentials per database type. Host/port/database point at the
same target database as the runtime credentials so the bootstrap runs against it.
*/}}
{{- define "eoapi.postgresqlInitEnv" -}}
{{- if eq .Values.postgresql.type "postgrescluster" }}
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: user
- name: PGPORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: port
- name: PGHOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: host
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: password
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: dbname
{{- else }}
{{- $ext := .Values.postgresql.external }}
{{- $admin := $ext.admin }}
{{- /*
Admin credentials: an existingSecret is preferred when set, regardless of
postgresql.type, so a superuser password never has to live in plaintext values.
Falls back to admin.credentials.
*/ -}}
{{- if $admin.existingSecret.name }}
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ $admin.existingSecret.name }}
      key: {{ $admin.existingSecret.keys.username }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $admin.existingSecret.name }}
      key: {{ $admin.existingSecret.keys.password }}
{{- else }}
- name: PGUSER
  value: {{ $admin.credentials.username | quote }}
- name: PGPASSWORD
  value: {{ $admin.credentials.password | quote }}
{{- end }}
{{- /*
Connection target: same database as the runtime credentials. Read from the
runtime secret only when that is where those values live.
*/ -}}
{{- $fromSecret := eq .Values.postgresql.type "external-secret" }}
{{- if and $fromSecret $ext.existingSecret.keys.host }}
- name: PGHOST
  valueFrom:
    secretKeyRef:
      name: {{ $ext.existingSecret.name }}
      key: {{ $ext.existingSecret.keys.host }}
{{- else }}
- name: PGHOST
  value: {{ $ext.host | quote }}
{{- end }}
{{- if and $fromSecret $ext.existingSecret.keys.port }}
- name: PGPORT
  valueFrom:
    secretKeyRef:
      name: {{ $ext.existingSecret.name }}
      key: {{ $ext.existingSecret.keys.port }}
{{- else }}
- name: PGPORT
  value: {{ $ext.port | quote }}
{{- end }}
{{- if and $fromSecret $ext.existingSecret.keys.database }}
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: {{ $ext.existingSecret.name }}
      key: {{ $ext.existingSecret.keys.database }}
{{- else }}
- name: PGDATABASE
  value: {{ $ext.database | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
PostgreSQL cluster secrets
*/}}
{{- define "eoapi.postgresclusterSecrets" -}}
{{- range $userName, $v := .Values.postgrescluster.users -}}
{{/* do not render anything for the "postgres" user */}}
{{- if not (eq (index $v "name") "postgres") }}
# Standard PostgreSQL environment variables
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: user
- name: PGPORT
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: port
- name: PGHOST
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: host
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: password
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: dbname
- name: PGBOUNCER_URI
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: pgbouncer-uri
# Legacy variables for backward compatibility
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: user
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: port
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: host
- name: POSTGRES_HOST_READER
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: host
- name: POSTGRES_HOST_WRITER
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: host
- name: POSTGRES_PASS
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: password
- name: POSTGRES_DBNAME
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: dbname
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgrescluster.name | default $.Release.Name }}-pguser-{{ index $v "name" }}
      key: uri
{{- end }}
{{- end }}
- name: PGADMIN_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgrescluster.name | default .Release.Name }}-pguser-postgres
      key: uri
{{- end }}

{{/*
External PostgreSQL with plaintext credentials
*/}}
{{- define "eoapi.externalPlaintextPgSecrets" -}}
# Standard PostgreSQL environment variables
- name: PGUSER
  value: {{ .Values.postgresql.external.credentials.username | quote }}
- name: PGPORT
  value: {{ .Values.postgresql.external.port | quote }}
- name: PGHOST
  value: {{ .Values.postgresql.external.host | quote }}
- name: PGPASSWORD
  value: {{ .Values.postgresql.external.credentials.password | quote }}
- name: PGDATABASE
  value: {{ .Values.postgresql.external.database | quote }}
# Legacy variables for backward compatibility
- name: POSTGRES_USER
  value: {{ .Values.postgresql.external.credentials.username | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgresql.external.port | quote }}
- name: POSTGRES_HOST
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_HOST_READER
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_HOST_WRITER
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_PASS
  value: {{ .Values.postgresql.external.credentials.password | quote }}
- name: POSTGRES_DBNAME
  value: {{ .Values.postgresql.external.database | quote }}
- name: DATABASE_URL
  value: "postgresql://{{ .Values.postgresql.external.credentials.username }}:{{ .Values.postgresql.external.credentials.password }}@{{ .Values.postgresql.external.host }}:{{ .Values.postgresql.external.port }}/{{ .Values.postgresql.external.database }}"
{{- end }}

{{/*
External PostgreSQL with secret credentials
*/}}
{{- define "eoapi.externalSecretPgSecrets" -}}
# Standard PostgreSQL environment variables
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.username }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.password }}
# Legacy variables for backward compatibility
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.username }}
- name: POSTGRES_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.password }}

# Host, port, and database can be from the secret or from values
{{- if .Values.postgresql.external.existingSecret.keys.host }}
- name: PGHOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.host }}
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.host }}
- name: POSTGRES_HOST_READER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.host }}
- name: POSTGRES_HOST_WRITER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.host }}
{{- else }}
- name: PGHOST
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_HOST
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_HOST_READER
  value: {{ .Values.postgresql.external.host | quote }}
- name: POSTGRES_HOST_WRITER
  value: {{ .Values.postgresql.external.host | quote }}
{{- end }}

{{- if .Values.postgresql.external.existingSecret.keys.port }}
- name: PGPORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.port }}
- name: POSTGRES_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.port }}
{{- else }}
- name: PGPORT
  value: {{ .Values.postgresql.external.port | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgresql.external.port | quote }}
{{- end }}

{{- if .Values.postgresql.external.existingSecret.keys.database }}
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.database }}
- name: POSTGRES_DBNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.database }}
{{- else }}
- name: PGDATABASE
  value: {{ .Values.postgresql.external.database | quote }}
- name: POSTGRES_DBNAME
  value: {{ .Values.postgresql.external.database | quote }}
{{- end }}

# Add DATABASE_URL for connection string
{{- if .Values.postgresql.external.existingSecret.keys.uri }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.external.existingSecret.name }}
      key: {{ .Values.postgresql.external.existingSecret.keys.uri }}
{{- else }}
- name: DATABASE_URL
  value: "postgresql://$(PGUSER):$(PGPASSWORD)@$(PGHOST):$(PGPORT)/$(PGDATABASE)"
{{- end }}
{{- end }}

{{/*
Validate PostgreSQL configuration
*/}}
{{- define "eoapi.validatePostgresql" -}}
{{- if eq .Values.postgresql.type "postgrescluster" }}
  {{- if not .Values.postgrescluster.enabled }}
    {{- fail "When postgresql.type is 'postgrescluster', postgrescluster.enabled must be true" }}
  {{- end }}
  {{- include "eoapi.validatePostgresCluster" . }}
{{- else if eq .Values.postgresql.type "external-plaintext" }}
  {{- if .Values.postgrescluster.enabled }}
    {{- fail "When postgresql.type is 'external-plaintext', postgrescluster.enabled must be set to false" }}
  {{- end }}
  {{- if not .Values.postgresql.external.host }}
    {{- fail "When postgresql.type is 'external-plaintext', postgresql.external.host must be set" }}
  {{- end }}
  {{- if not .Values.postgresql.external.credentials.username }}
    {{- fail "When postgresql.type is 'external-plaintext', postgresql.external.credentials.username must be set" }}
  {{- end }}
  {{- if not .Values.postgresql.external.credentials.password }}
    {{- fail "When postgresql.type is 'external-plaintext', postgresql.external.credentials.password must be set" }}
  {{- end }}
{{- else if eq .Values.postgresql.type "external-secret" }}
  {{- if .Values.postgrescluster.enabled }}
    {{- fail "When postgresql.type is 'external-secret', postgrescluster.enabled must be set to false" }}
  {{- end }}
  {{- if not .Values.postgresql.external.existingSecret.name }}
    {{- fail "When postgresql.type is 'external-secret', postgresql.external.existingSecret.name must be set" }}
  {{- end }}
  {{- if not .Values.postgresql.external.existingSecret.keys.username }}
    {{- fail "When postgresql.type is 'external-secret', postgresql.external.existingSecret.keys.username must be set" }}
  {{- end }}
  {{- if not .Values.postgresql.external.existingSecret.keys.password }}
    {{- fail "When postgresql.type is 'external-secret', postgresql.external.existingSecret.keys.password must be set" }}
  {{- end }}
  {{- if not .Values.postgresql.external.existingSecret.keys.host }}
    {{- if not .Values.postgresql.external.host }}
      {{- fail "When postgresql.type is 'external-secret' and existingSecret.keys.host is not set, postgresql.external.host must be set" }}
    {{- end }}
  {{- end }}
{{- else }}
  {{- fail "postgresql.type must be one of: 'postgrescluster', 'external-plaintext', 'external-secret'" }}
{{- end }}
{{- end }}

{{/*
validate:
1. the .Values.postgrescluster.users array does not have more than two elements.
2. at least one of the users is named "postgres".
*/}}
{{- define "eoapi.validatePostgresCluster" -}}
{{- $users := .Values.postgrescluster.users | default (list) -}}

{{- if gt (len $users) 2 -}}
  {{- fail "The users array in postgrescluster should not have more than two users declared b/c the last user declared will override all secrets generated in eoapi.pgstacSecrets" -}}
{{- end -}}

{{- $hasPostgres := false -}}
{{- range $index, $user := $users -}}
  {{- if eq $user.name "postgres" -}}
    {{- $hasPostgres = true -}}
  {{- end -}}
{{- end -}}

{{- if not $hasPostgres -}}
  {{- fail "The users array in postgrescluster must contain at least one user named 'postgres'." -}}
{{- end -}}

{{- end -}}
