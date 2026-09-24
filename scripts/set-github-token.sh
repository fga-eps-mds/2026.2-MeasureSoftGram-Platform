#!/usr/bin/env bash
# Grava um token do GitHub no perfil de um usuario (campo
# CustomUser.github_access_token), que e o que os endpoints
# /accounts/github-organizations/ e afins consultam PRIMEIRO.
#
# Necessario porque esta versao do Service roda django-allauth com
# SOCIALACCOUNT_STORE_TOKENS=False: ao "Entrar com GitHub" a conta e
# vinculada mas o access token do OAuth NAO e persistido. Ate o Service
# corrigir isso, use um PAT aqui.
#
#   ./scripts/set-github-token.sh <username>            # usa GITHUB_TOKEN do .env
#   ./scripts/set-github-token.sh <username> ghp_xxx    # token explicito
set -euo pipefail
cd "$(dirname "$0")/.."

USER_NAME="${1:?uso: set-github-token.sh <username> [token]}"
TOKEN="${2:-$(grep -E '^GITHUB_TOKEN=' .env | cut -d= -f2- | tr -d '\r"')}"
[ -n "$TOKEN" ] || { echo "sem token: passe como 2o arg ou preencha GITHUB_TOKEN no .env" >&2; exit 1; }

docker compose --env-file .env exec -T service python manage.py shell -c "
from django.contrib.auth import get_user_model
U = get_user_model()
u = U.objects.filter(username='${USER_NAME}').first()
if not u:
    raise SystemExit('usuario \"${USER_NAME}\" nao existe (loga uma vez para cria-lo)')
u.github_access_token = '${TOKEN}'
u.save()
print('token gravado para ${USER_NAME} (len', len(u.github_access_token), ')')
"
