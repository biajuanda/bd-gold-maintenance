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
refresh_view "retention.chats_eva"

# --- Retention (kustomer + hubspot) ------------------------------------------
refresh_view "retention.kustomer_cx"                       "CONCURRENTLY"

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
refresh_view "finance.collections_bills_issued_by_period"    "CONCURRENTLY"
refresh_view "finance.collections_recaudo_detail"            "CONCURRENTLY"
refresh_view "finance.collections_portfolio_cadence"         "CONCURRENTLY"
refresh_view "finance.collections_daily_accumulated"         "CONCURRENTLY"
refresh_view "finance.collections_success_flow_bills"        "CONCURRENTLY"

# --- Energy / Tarifas (Desviaciones KR9 + Competitividad KR8/KR10/KR11) -------
# 8 matviews backing /energy/desviaciones/tarifa and /energy/competitiveness/*.
# All ship with UNIQUE INDEXes on plain columns so CONCURRENTLY works.
# Order respects internal dependencies: comp_all_agents and comp_dcr feed
# comp_agent_market, which in turn feeds comp_ranking_monthly. CONCURRENTLY
# refreshes do not block readers, so the temporary intra-batch staleness
# during a refresh window is acceptable. comp_tarifa_long es independiente
# (lee directo de calculator-prices.rates + bia-ml.simulation_results via
# dblink, no depende de otras matviews). Ver
# bia-growth-status-back/docs/gold-schema/energy-tarifas.sql
refresh_view "energy.comp_all_agents"                        "CONCURRENTLY"
refresh_view "energy.comp_dcr"                               "CONCURRENTLY"
refresh_view "energy.comp_bia_pub"                           "CONCURRENTLY"
refresh_view "energy.comp_agent_market"                      "CONCURRENTLY"
refresh_view "energy.comp_ranking_monthly"                   "CONCURRENTLY"
refresh_view "energy.comp_evolution"                         "CONCURRENTLY"
refresh_view "energy.desv_tarifa"                            "CONCURRENTLY"
refresh_view "energy.comp_tarifa_long"                       "CONCURRENTLY"

# --- Energy / Portafolio (Demanda) + Trading (Posición de Bolsa) -------------
# 6 matviews backing /energy/demand/{monthly,daily,hourly-curve} and
# /energy/position/{hourly,summary}. All ship with plain-column UNIQUE INDEXes
# so CONCURRENTLY works. Sources: file-compiler.{adem_public, tgrl_public,
# trsd_public}, filtered to file_date >= '2024-01-01'. position_avg_prices
# pre-joins tgrl × trsd (PBNA Tx2). Ver
# bia-growth-status-back/docs/gold-schema/energy-portafolio-trading.sql
refresh_view "energy.demand_monthly"                         "CONCURRENTLY"
refresh_view "energy.demand_daily"                           "CONCURRENTLY"
refresh_view "energy.demand_hourly_curve"                    "CONCURRENTLY"
refresh_view "energy.position_hourly"                        "CONCURRENTLY"
refresh_view "energy.position_volumes"                       "CONCURRENTLY"
refresh_view "energy.position_avg_prices"                    "CONCURRENTLY"

# --- Energy / Precio de Bolsa (PB hourly + daily + tipo-día curve) -----------
# 3 matviews backing /energy/price/{hourly-curve,pb-historical,monthly,pb-min-avg-max}.
# All ship with plain-column UNIQUE INDEXes so CONCURRENTLY works.
# Source: file-compiler.trsd_public filtered to code='PBNA' and
# version_file IN ('Tx1','Tx2'), file_date >= '2024-01-01'. Ver
# bia-growth-status-back/docs/gold-schema/energy-precio-bolsa.sql
refresh_view "energy.price_pb_hourly_curve"                  "CONCURRENTLY"
refresh_view "energy.price_pb_hourly"                        "CONCURRENTLY"
refresh_view "energy.price_pb_daily"                         "CONCURRENTLY"
# --- CGM (Consumos) ----------------------------------------------------------

refresh_view "cgm.consumos_diarios"      			"CONCURRENTLY"
refresh_view "cgm.lecturas_horarias_diarias"     	"CONCURRENTLY"
refresh_view "cgm.lecturas_horarias_medidor"      	"CONCURRENTLY"

# --- Acquisition (HubSpot funnel) --------------------------------------------
# Sin CONCURRENTLY: las vistas no tienen UNIQUE INDEX sobre PK lógica.
# Consolida en una fila por entidad todas las etapas del embudo de adquisición
# (desde primer contacto en HubSpot hasta deal ganado) para análisis de
# pipeline comercial sin JOINs ad-hoc.
refresh_view "acquisition.acquisition_funnel"               "CONCURRENTLY"
# Consolida una frontera por cada deal que se puede conectar con acquisition_funnel.
refresh_view "acquisition.deal_fronteras"                   "CONCURRENTLY"

echo "Mantenimiento finalizado con éxito."
