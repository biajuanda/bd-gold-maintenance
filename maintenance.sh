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

echo "Iniciando mantenimiento de vistas de Mixpanel..."

# Ejecutamos ambos refrescos en estricto orden.
# Si mas adelante creas los indices unicos requeridos, puedes evaluar usar CONCURRENTLY.
echo "Actualizando base de eventos..."
PGPASSWORD="${DB_PASSWORD_VALUE}" psql \
  -U "${DB_USER_VALUE}" \
  -h "${DB_HOST_VALUE}" \
  -p "${DB_PORT_VALUE}" \
  -d "${DB_NAME_VALUE}" \
  -v ON_ERROR_STOP=1 \
  -c "REFRESH MATERIALIZED VIEW retention.mixpanel_events;"

echo "Actualizando base de sesiones..."
PGPASSWORD="${DB_PASSWORD_VALUE}" psql \
  -U "${DB_USER_VALUE}" \
  -h "${DB_HOST_VALUE}" \
  -p "${DB_PORT_VALUE}" \
  -d "${DB_NAME_VALUE}" \
  -v ON_ERROR_STOP=1 \
  -c "REFRESH MATERIALIZED VIEW retention.mixpanel_sessions;"

echo "Mantenimiento finalizado con éxito."
