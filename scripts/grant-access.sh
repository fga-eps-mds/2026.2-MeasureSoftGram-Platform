#!/usr/bin/env bash
# Torna um usuario membro (e admin, se a org nao tiver um) de TODAS as
# organizacoes. Util para enxergar os dados fake do seed quando voce loga
# com admin/admin em vez de "Entrar com GitHub".
#
#   ./scripts/grant-access.sh admin
#   ./scripts/grant-access.sh <seu-login-github>
set -euo pipefail
cd "$(dirname "$0")/.."

USER_NAME="${1:?uso: grant-access.sh <username>}"

docker compose --env-file .env exec -T service python manage.py shell -c "
from organizations.models import Organization
from django.contrib.auth import get_user_model
U = get_user_model()
u = U.objects.filter(username='${USER_NAME}').first()
if not u:
    raise SystemExit('usuario \"${USER_NAME}\" nao existe (loga uma vez para cria-lo)')
n = 0
for o in Organization.objects.all():
    o.members.add(u)
    if o.admin is None:
        o.admin = u; o.save()
    n += 1
print('${USER_NAME} agora e membro de', n, 'organizacoes')
"
