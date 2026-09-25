# ============================================================
# CLI (msgram) + Core + Parser instalados do CODIGO LOCAL dos submodulos.
# Contexto de build = raiz do Platform (precisa dos tres submodulos).
# Instalar Core e Parser ANTES do CLI faz o pip aceitar as versoes
# locais em vez de baixar do PyPI.
# ============================================================
FROM python:3.12-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

COPY Core   /src/core
COPY Parser /src/parser
COPY CLI    /src/cli

RUN pip install -e /src/core -e /src/parser \
    && pip install -e /src/cli

WORKDIR /workspace

ENTRYPOINT ["msgram"]
