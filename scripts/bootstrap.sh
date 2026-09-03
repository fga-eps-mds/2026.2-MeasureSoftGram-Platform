#!/usr/bin/env bash
# Sobe a stack do zero: submodulos -> .env -> build -> up -> smoke test.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Sincronizando submodulos"
git submodule update --init --recursive

if [ ! -f .env ]; then
  echo "==> Criando .env a partir de .env.example (preencha o GitHub OAuth depois)"
  cp .env.example .env
fi

echo "==> Build das imagens (primeira vez: ~5-10 min)"
docker compose --env-file .env build

echo "==> Subindo a stack"
docker compose --env-file .env up -d

echo "==> Smoke test"
exec ./scripts/smoke-test.sh
