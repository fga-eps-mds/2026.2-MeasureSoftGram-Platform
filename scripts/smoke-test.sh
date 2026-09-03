#!/usr/bin/env bash
# Verifica que o produto inteiro respondeu atras do proxy. Retry ate 120s.
# Tambem e o job do CI (.github/workflows/compose-smoke.yml).
set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${PUBLIC_URL:-http://localhost}"
[ -f .env ] && BASE="$(grep -E '^PUBLIC_URL=' .env | cut -d= -f2- | tr -d '\r' | xargs || true)"
BASE="${BASE:-http://localhost}"

DEADLINE=$(( $(date +%s) + 120 ))

check() { # <descricao> <url> <regex de status aceitos>
  local desc="$1" url="$2" ok="$3" code
  while :; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo 000)
    if [[ "$code" =~ $ok ]]; then
      echo "  OK  [$code] $desc"
      return 0
    fi
    if (( $(date +%s) > DEADLINE )); then
      echo "  FAIL [$code] $desc ($url)"
      return 1
    fi
    sleep 3
  done
}

echo "==> Smoke test em $BASE"
rc=0
check "landing (/)"                      "$BASE/"                              '^200$'        || rc=1
check "swagger"                          "$BASE/swagger/"                      '^200$'        || rc=1
check "DRF supported-metrics"            "$BASE/api/v1/supported-metrics/"     '^(200|401|403)$' || rc=1
check "django admin login"              "$BASE/admin/login/"                  '^200$'        || rc=1
check "grafana health"                   "$BASE/grafana/api/health"           '^200$'        || rc=1

if [ "$rc" -ne 0 ]; then
  echo "==> Smoke test FALHOU"
  exit 1
fi
echo "==> Smoke test OK"
