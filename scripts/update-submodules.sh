#!/usr/bin/env bash
# Avanca todos os submodulos para o topo do branch configurado (develop).
set -euo pipefail
cd "$(dirname "$0")/.."
git submodule update --remote --merge
git submodule foreach 'git log --oneline -1'
echo "==> Revise e commite os ponteiros: git add MeasureSoftGram-* && git commit"
