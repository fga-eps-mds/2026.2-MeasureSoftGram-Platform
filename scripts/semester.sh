#!/usr/bin/env bash
# ============================================================
# Fluxo de trabalho por semestre.
#
# A cada semestre a equipe forka os 9 repos na PROPRIA org, prefixando
# pelo NUMERO DO SEMESTRE no padrao AAAA.S (ano com 4 digitos, ponto,
# 1 ou 2) — ex.: fga-eps-mds/2026.2-MeasureSoftGram-*. Esse numero muda
# a cada semestre; "2026.2" aqui e so o exemplo do semestre corrente.
# A equipe trabalha o semestre inteiro so no fork. No fork do Platform,
# o `.gitmodules` e REESCRITO E COMMITADO apontando para os <SEM>-* — e
# so esse commit que diferencia estruturalmente o fork do central.
#
#   ./scripts/semester.sh use <AAAA.S> # ex.: use 2026.2 -> reescreve .gitmodules
#   ./scripts/semester.sh reset        # volta .gitmodules -> fga-eps-mds/*
#   ./scripts/semester.sh status       # URL efetiva de cada submodulo
#
# IMPORTANTE: o `path` de cada submodulo NUNCA muda (continua
# MeasureSoftGram-Service etc.) — so a URL. docker-compose.yml,
# docker/cli/Dockerfile e nginx/ dependem desses paths.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/.."

ORG=fga-eps-mds
REPOS=(Service Front Core Parser CLI Action Plugin AI)

usage() {
  echo "uso: semester.sh use <AAAA.S> | reset | status" >&2
  echo "     <AAAA.S> = semestre no padrao ano.semestre (ex.: 2026.2, 2027.1)" >&2
  exit 1
}

infer_semester() {
  # semestre inferido da primeira URL 2026.2-* no .gitmodules
  git config -f .gitmodules --get-regexp '^submodule\..*\.url$' \
    | grep -oE '/[0-9]{4}\.[12]-MeasureSoftGram-' \
    | head -1 | grep -oE '[0-9]{4}\.[12]' || true
}

cmd="${1:-}"
case "$cmd" in
  use)
    sem="${2:-}"
    [[ "$sem" =~ ^[0-9]{4}\.[12]$ ]] || {
      echo "semestre invalido: '${sem:-}' — formato esperado AAAA.S (ex.: 2026.2)" >&2
      exit 1
    }
    for r in "${REPOS[@]}"; do
      p="MeasureSoftGram-$r"
      git submodule set-url "$p" "https://github.com/$ORG/$sem-MeasureSoftGram-$r.git"
      echo "  $p -> $sem-MeasureSoftGram-$r"
    done
    git submodule sync
    echo "==> Buscando o codigo do semestre..."
    git submodule update --init --remote
    echo "==> .gitmodules reescrito. Commite:"
    echo "    git add .gitmodules && git commit -m 'chore: aponta submodulos para $sem-*'"
    ;;
  reset)
    for r in "${REPOS[@]}"; do
      p="MeasureSoftGram-$r"
      git submodule set-url "$p" "https://github.com/$ORG/MeasureSoftGram-$r.git"
      echo "  $p -> MeasureSoftGram-$r"
    done
    git submodule sync
    echo "==> .gitmodules de volta para $ORG/MeasureSoftGram-* (central)."
    ;;
  status)
    sem="$(infer_semester)"
    echo "==> Semestre configurado: ${sem:-<nenhum> (central)}"
    for r in "${REPOS[@]}"; do
      p="MeasureSoftGram-$r"
      printf '  %-26s %s\n' "$p" "$(git config -f .gitmodules --get "submodule.$p.url")"
    done
    ;;
  *)
    usage
    ;;
esac
