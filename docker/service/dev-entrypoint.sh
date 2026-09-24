#!/usr/bin/env bash
# Entrypoint de DEV do container "service", montado pelo docker-compose por
# cima do Dockerfile.dev do submodulo (que so faz `manage.py runserver`, sem
# migrar/semear o banco). Refaz o essencial de start_service.sh mas termina
# com `runserver` em vez de gunicorn: reload nativo do Django, sem flags de
# terceiros, funciona igual em qualquer SO.
set -euo pipefail

echo "======= AGUARDANDO POSTGRES"
until (echo > "/dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}") 2>/dev/null; do
  sleep 1
done
echo "======= POSTGRES OK"

echo "======= RUNNING MIGRATIONS"
python3 manage.py migrate --noinput

if [[ "${RUN_LOAD_INITIAL_DATA:-true}" = "true" ]]; then
  echo "======= PREPOPULATING THE DATABASE"
  python3 manage.py load_initial_data
else
  echo "======= SKIPPING load_initial_data (RUN_LOAD_INITIAL_DATA != true)"
fi

echo "======= COLLECTING STATIC FILES"
python3 manage.py collectstatic --noinput

echo "======= RUNNING DJANGO DEV SERVER (hot reload nativo)"
exec python3 manage.py runserver 0.0.0.0:8080
