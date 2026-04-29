#!/bin/bash
set -euo pipefail

DB_HOST_VALUE="${DB_HOST:-${POSTGRES_HOST_GOLD:-}}"
DB_PORT_VALUE="${DB_PORT:-${POSTGRES_PORT_GOLD:-5432}}"
DB_NAME_VALUE="${DB_NAME:-${POSTGRES_DB_GOLD:-bia-gold}}"
DB_USER_VALUE="${DB_USER:-${POSTGRES_USER_GOLD:-}}"
DB_PASSWORD_VALUE="${DB_PGPASSWORD:-${POSTGRES_PASSWORD_GOLD:-}}"

if [ -z "${DB_HOST_VALUE}" ] || [ -z "${DB_USER_VALUE}" ] || [ -z "${DB_PASSWORD_VALUE}" ]; then
  echo "Faltan variables de conexion a la base de datos."
  echo "Define DB_HOST/DB_USER/DB_PGPASSWORD o POSTGRES_HOST_GOLD/POSTGRES_USER_GOLD/POSTGRES_PASSWORD_GOLD."
  exit 1
fi

echo "Iniciando mantenimiento de vistas materializadas..."

# Helper: corre un REFRESH (con o sin CONCURRENTLY) y loguea pasos.
# Uso: refresh_view "<nombre.cualificado>" [CONCURRENTLY]
refresh_view() {
  local view_name="$1"
  local concurrently="${2:-}"
  local sql

  if [ "${concurrently}" = "CONCURRENTLY" ]; then
    sql="REFRESH MATERIALIZED VIEW CONCURRENTLY ${view_name};"
  else
    sql="REFRESH MATERIALIZED VIEW ${view_name};"
  fi

  echo "Actualizando ${view_name}..."
  PGPASSWORD="${DB_PASSWORD_VALUE}" psql \
    -U "${DB_USER_VALUE}" \
    -h "${DB_HOST_VALUE}" \
    -p "${DB_PORT_VALUE}" \
    -d "${DB_NAME_VALUE}" \
    -v ON_ERROR_STOP=1 \
    -c "${sql}"
}

# --- Retention (Mixpanel) ----------------------------------------------------
# Sin CONCURRENTLY: estas vistas no tienen los indices unicos requeridos.
refresh_view "retention.mixpanel_events"
refresh_view "retention.mixpanel_sessions"

# --- Finance / Comunicaciones (Sendgrid funnel + bills coverage) -------------
# CONCURRENTLY: las matviews tienen UNIQUE INDEX (idx_*_pk) sobre la PK logica,
# lo cual permite refrescar sin bloquear lectores. Ver
# bia-growth-status-back/docs/gold-schema/finance-comunicaciones.sql
refresh_view "finance.bills_communications_period"           "CONCURRENTLY"
refresh_view "finance.communications_message_aggregated"     "CONCURRENTLY"
refresh_view "finance.communications_message_lifecycle"      "CONCURRENTLY"

echo "Mantenimiento finalizado con éxito."
