#!/usr/bin/env bash
# Reescreve as URLs dos submodulos para os forks de <usuario-github>.
# Fluxo: voce trabalha no SEU fork e abre PR para fga-eps-mds/*.
#   ./scripts/use-fork.sh meu-usuario
#   ./scripts/use-fork.sh --reset          # volta para fga-eps-mds
set -euo pipefail
cd "$(dirname "$0")/.."

REPOS=(Service Front Core Parser CLI Action)

if [ "${1:-}" = "--reset" ]; then
  NS="fga-eps-mds"
else
  NS="${1:?uso: use-fork.sh <usuario-github> | --reset}"
fi

for r in "${REPOS[@]}"; do
  path="MeasureSoftGram-$r"
  url="https://github.com/$NS/MeasureSoftGram-$r.git"
  git config -f .gitmodules "submodule.$path.url" "$url"
  git submodule sync -- "$path"
  echo "  $path -> $url"
done

echo "==> Rode: git submodule update --remote --init"
