#!/usr/bin/env bash
# ============================================================
# Aponta os submodulos para os SEUS forks — SEM tocar em .gitmodules.
#
# A troca e gravada so no .git/config local (override que o
# `git submodule update` respeita). O .gitmodules versionado continua
# apontando para fga-eps-mds/*, entao um PR de bump de ponteiro no
# Platform nunca vaza URL de fork.
#
#   ./scripts/use-fork.sh <usuario-github>   # usa seus forks
#   ./scripts/use-fork.sh --reset            # volta para fga-eps-mds
#   ./scripts/use-fork.sh --status           # mostra a URL efetiva de cada um
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/.."

REPOS=(Service Front Core Parser CLI Action)

case "${1:-}" in
  --status)
    for r in "${REPOS[@]}"; do
      p="MeasureSoftGram-$r"
      printf '  %-24s %s\n' "$p" "$(git config --get "submodule.$p.url" || echo '(default do .gitmodules)')"
    done
    exit 0
    ;;
  --reset)
    git submodule init
    for r in "${REPOS[@]}"; do
      p="MeasureSoftGram-$r"
      git config --unset "submodule.$p.url" 2>/dev/null || true
      git submodule sync -- "$p" >/dev/null
      echo "  $p -> $(git config --get "submodule.$p.url")"
    done
    echo "==> Rode: git submodule update --remote"
    exit 0
    ;;
  "")
    echo "uso: use-fork.sh <usuario-github> | --reset | --status" >&2
    exit 1
    ;;
esac

GH_USER="$1"
git submodule init   # garante que as entradas existem no .git/config
for r in "${REPOS[@]}"; do
  p="MeasureSoftGram-$r"
  url="https://github.com/$GH_USER/MeasureSoftGram-$r.git"
  git config "submodule.$p.url" "$url"     # override LOCAL, nao versionado
  echo "  $p -> $url"
done

echo "==> Agora rode: git submodule update --remote --init"
echo "    (.gitmodules NAO foi alterado — segue apontando para fga-eps-mds/*)"
