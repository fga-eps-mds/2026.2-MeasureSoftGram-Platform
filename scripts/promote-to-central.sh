#!/usr/bin/env bash
# ============================================================
# Promocao do fork de semestre do Platform -> central.
#
# Um submodulo grava URL (.gitmodules) E commit (ponteiro na arvore). No
# fork de semestre os dois divergem do central: as URLs viram 2026.2-* e
# os ponteiros apontam para commits que SO existem nos 2026.2-*. Entao o
# merge 2026.2-MeasureSoftGram-Platform -> central nao pode ser cru.
#
# Ordem correta:
#   1. mergear cada 2026.2-MeasureSoftGram-X -> X central (develop) PRIMEIRO;
#   2. so entao, aqui: semester.sh reset + este script + PR do Platform.
#
# Este script (sem argumentos, rodado no fork de semestre do Platform):
#   - assume que voce ja rodou `./scripts/semester.sh reset` (URLs centrais);
#   - verifica, para cada submodulo, se o commit apontado JA existe em
#     origin/develop do central;
#   - lista os que faltam e sai != 0 — nada e commitado/pushado.
#   - se todos passarem, avanca os ponteiros para o topo de develop central
#     e imprime o `git add`/`commit` sugerido.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/.."

REPOS=(Service Front Core Parser CLI Action Plugin AI)

# guard: .gitmodules precisa estar nas URLs centrais
if git config -f .gitmodules --get-regexp '^submodule\..*\.url$' | grep -qE '/[0-9]{4}\.[12]-MeasureSoftGram-'; then
  echo "ERRO: .gitmodules ainda aponta para forks de semestre." >&2
  echo "      Rode primeiro: ./scripts/semester.sh reset" >&2
  exit 1
fi

git submodule sync >/dev/null

missing=()
for r in "${REPOS[@]}"; do
  p="MeasureSoftGram-$r"
  ptr="$(git -C "$p" rev-parse HEAD)"
  git -C "$p" fetch -q origin develop
  if git -C "$p" merge-base --is-ancestor "$ptr" origin/develop 2>/dev/null; then
    echo "  OK   $p  ($ptr)"
  else
    echo "  FALTA $p  ($ptr) — nao esta em origin/develop do central"
    missing+=("$r")
  fi
done

if (( ${#missing[@]} )); then
  echo
  echo "==> Mergeie estes forks de semestre -> central (develop) antes:"
  for r in "${missing[@]}"; do
    echo "      2026.2-MeasureSoftGram-$r  ->  fga-eps-mds/MeasureSoftGram-$r"
  done
  exit 1
fi

echo
echo "==> Todos os ponteiros existem no central. Avancando para o topo de develop..."
./scripts/update-submodules.sh

echo
echo "==> Revise o diff (deve conter .gitmodules -> fga-eps-mds/* + ponteiros) e commite:"
echo "    git add .gitmodules MeasureSoftGram-*"
echo "    git commit -m 'chore: promove submodulos do semestre para o central'"
