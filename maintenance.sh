#!/bin/bash
set -euo pipefail

DB_HOST_VALUE="${DB_HOST:-${POSTGRES_HOST_GOLD:-}}"
DB_PORT_VALUE="${DB_PORT:-${POSTGRES_PORT_GOLD:-5432}}"
DB_NAME_VALUE="${DB_NAME:-${POSTGRES_DB_GOLD:-bia-gold}}"
DB_USER_VALUE="${DB_USER:-${POSTGRES_USER_GOLD:-}}"
DB_PASSWORD_VALUE="${DB_PGPASSWORD:-${POSTGRES_PASSWORD_GOLD:-}}"
MATERIALIZED_VIEW_NAME="${MATERIALIZED_VIEW_NAME:-retention.mixpanel_events}"

if [ -z "${DB_HOST_VALUE}" ] || [ -z "${DB_USER_VALUE}" ] || [ -z "${DB_PASSWORD_VALUE}" ]; then
  echo "Faltan variables de conexion a la base de datos."
  echo "Define DB_HOST/DB_USER/DB_PGPASSWORD o POSTGRES_HOST_GOLD/POSTGRES_USER_GOLD/POSTGRES_PASSWORD_GOLD."
  exit 1
fi

echo "Ejecutando mantenimiento de vista materializada ${MATERIALIZED_VIEW_NAME}..."
PGPASSWORD="${DB_PASSWORD_VALUE}" psql \
  -U "${DB_USER_VALUE}" \
  -h "${DB_HOST_VALUE}" \
  -p "${DB_PORT_VALUE}" \
  -d "${DB_NAME_VALUE}" \
  -c "REFRESH MATERIALIZED VIEW ${MATERIALIZED_VIEW_NAME};"
echo "Mantenimiento finalizado."
