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

# --- Finance / Recaudo (Facturación & Pagos) ---------------------------------
# 10 matviews que reemplazan los queries en vivo del repo Go contra bia-bills
# y bia-payments. Cada una tiene UNIQUE INDEX, por eso CONCURRENTLY. Ver
# bia-growth-status-back/docs/gold-schema/finance-recaudo.sql
refresh_view "finance.billing_history_monthly"               "CONCURRENTLY"
refresh_view "finance.collections_okr_compliance"            "CONCURRENTLY"
refresh_view "finance.collections_payment_buckets"           "CONCURRENTLY"
refresh_view "finance.collections_platforms_distribution"    "CONCURRENTLY"
refresh_view "finance.collections_payment_methods_distrib"   "CONCURRENTLY"
refresh_view "finance.collections_debit_type_summary"        "CONCURRENTLY"
refresh_view "finance.collections_recaudo_detail"            "CONCURRENTLY"
refresh_view "finance.collections_portfolio_cadence"         "CONCURRENTLY"
refresh_view "finance.collections_daily_accumulated"         "CONCURRENTLY"
refresh_view "finance.collections_success_flow_bills"        "CONCURRENTLY"

# --- Acquisition (HubSpot funnel) --------------------------------------------
# Sin CONCURRENTLY: la vista no tiene UNIQUE INDEX sobre PK lógica.
# Consolida en una fila por entidad todas las etapas del embudo de adquisición
# (desde primer contacto en HubSpot hasta deal ganado) para análisis de
# pipeline comercial sin JOINs ad-hoc.
refresh_view "acquisition.acquisition_funnel"

echo "Mantenimiento finalizado con éxito."
