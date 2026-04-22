# bd-gold-maintenance

Contenedor para ejecutar tareas de mantenimiento sobre PostgreSQL desde un scheduled task en AWS.

## Seguridad

Este repositorio puede ser publico. No debes versionar credenciales reales.

- `.env` esta ignorado por Git y por Docker.
- Usa `.env.example` solo como plantilla local.
- Inyecta las credenciales en AWS como variables de entorno o, preferiblemente, desde AWS Secrets Manager o Parameter Store.

## Variables de entorno soportadas

El script acepta cualquiera de estos formatos:

- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PGPASSWORD`
- `POSTGRES_HOST_GOLD`, `POSTGRES_PORT_GOLD`, `POSTGRES_DB_GOLD`, `POSTGRES_USER_GOLD`, `POSTGRES_PASSWORD_GOLD`

Opcionalmente puedes definir:

- `MATERIALIZED_VIEW_NAME` para cambiar la vista a refrescar. Por defecto usa `retention.mixpanel_events`.
- `PGSSLMODE` si tu conexion requiere SSL. Un valor comun es `require`.

## Ejecucion local

```bash
docker build -t bd-gold-maintenance .
docker run --rm --env-file .env bd-gold-maintenance
```

## Comportamiento

El contenedor ejecuta:

```sql
REFRESH MATERIALIZED VIEW retention.mixpanel_events;
```

Si defines `MATERIALIZED_VIEW_NAME`, usara ese valor en lugar del default.

## Variables recomendadas en AWS

Para el scheduled task, define estas variables en AWS y no en el repo:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PGPASSWORD`
- `PGSSLMODE` si aplica
- `MATERIALIZED_VIEW_NAME` solo si quieres cambiar la vista por defecto
