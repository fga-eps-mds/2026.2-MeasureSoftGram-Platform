# Contribuindo com o MeasureSoftGram-Platform

## O que vive aqui

Somente a **orquestração**: `docker-compose.yml`, `nginx/`, `docker/cli/`,
`scripts/`, `Makefile`, CI e docs. Mudanças de código de aplicação vão nos
repositórios de cada componente (os submódulos `MeasureSoftGram-*`).

## Setup de desenvolvimento

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/2026.2-MeasureSoftGram-Platform.git
cd 2026.2-MeasureSoftGram-Platform
cp .env.example .env
make select && make up
```

Detalhes no [README](README.md).

## Alterando um componente

1. `cd MeasureSoftGram-<Componente>`, branch a partir de `develop` (ou
   `main`, no caso do DOC), commit, push para `origin`; abra o PR dentro do
   próprio repositório do componente.
2. Depois do merge, no Platform: `cd MeasureSoftGram-<Componente> && git
   checkout develop && git pull`, volte pra raiz, `git add
   MeasureSoftGram-<Componente>`, commit e PR aqui — isso avança o ponteiro
   do submódulo para o commit novo.
3. O CI `compose-smoke` valida o bump antes do merge.

## Antes de abrir o PR

- `make clean && make up` sobe do zero sem erro.
- `make smoke` passa (o CI `compose-smoke` roda o mesmo script).
- Commits no imperativo; PR descreve o "porquê".
