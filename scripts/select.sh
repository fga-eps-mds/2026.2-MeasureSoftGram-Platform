#!/usr/bin/env bash
# Menu interativo para escolher quais servicos sobem: le/reescreve a linha
# COMPOSE_PROFILES do .env (cria o .env a partir do .env.example se faltar).
#
#   ./scripts/select.sh          # make select
set -uo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "==> Criando .env a partir de .env.example"; cp .env.example .env; }

ALL=(service front grafana ai docs)
declare -A LABEL=(
  [service]="API Django (hot reload)"
  [front]="Next.js — Front (hot reload)"
  [grafana]="Dashboards Grafana"
  [ai]="Servidor MCP / AI (hot reload)"
  [docs]="Documentacao Docusaurus (hot reload)"
)

current="$(grep -E '^COMPOSE_PROFILES=' .env | head -1 | cut -d= -f2- | tr -d '\r"')"
declare -A ON
IFS=',' read -ra parts <<< "$current"
for p in "${parts[@]}"; do
  p="$(echo "$p" | xargs)"
  [ -n "$p" ] && ON["$p"]=1
done

print_menu() {
  echo
  echo "==> Servicos (numero p/ marcar/desmarcar, Enter p/ salvar):"
  local i=1
  for s in "${ALL[@]}"; do
    local mark=" "
    [ "${ON[$s]:-0}" = "1" ] && mark="x"
    printf "  %d) [%s] %-8s %s\n" "$i" "$mark" "$s" "${LABEL[$s]}"
    i=$((i + 1))
  done
  echo "  (front/service tambem trazem db + proxy automaticamente)"
}

while true; do
  print_menu
  read -rp "> " choice
  [ -z "$choice" ] && break
  idx=$((choice))
  if [ "$idx" -ge 1 ] && [ "$idx" -le "${#ALL[@]}" ] 2>/dev/null; then
    s="${ALL[$((idx - 1))]}"
    if [ "${ON[$s]:-0}" = "1" ]; then
      unset "ON[$s]"
    else
      ON["$s"]=1
    fi
  else
    echo "opcao invalida"
  fi
done

selected=()
for s in "${ALL[@]}"; do
  [ "${ON[$s]:-0}" = "1" ] && selected+=("$s")
done
new_line="COMPOSE_PROFILES=$(IFS=,; echo "${selected[*]}")"

if grep -qE '^COMPOSE_PROFILES=' .env; then
  tmp="$(mktemp)"
  sed -E "s/^COMPOSE_PROFILES=.*/${new_line//\//\\/}/" .env > "$tmp" && mv "$tmp" .env
else
  printf '%s\n' "$new_line" >> .env
fi

echo "==> .env atualizado: $new_line"

if [ "${#selected[@]}" -eq 0 ]; then
  echo "==> Nenhum servico selecionado — nada para subir."
  exit 0
fi

read -rp "Subir agora com 'docker compose up -d'? [s/N] " up
if [[ "$up" =~ ^[sS]$ ]]; then
  docker compose up -d
fi
