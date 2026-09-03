# Contribuindo com o MeasureSoftGram-Platform

Este repo segue o mesmo fluxo de governanca dos demais repositorios do
MeasureSoftGram: **fork -> branch -> Pull Request** para
`fga-eps-mds/MeasureSoftGram-Platform`.

## Setup de desenvolvimento

```bash
git clone --recurse-submodules <url-do-seu-fork>
cd MeasureSoftGram-Platform
cp .env.example .env
make setup
```

## O que vive aqui

Somente a **orquestracao**: `docker-compose.yml`, `nginx/`, `docker/cli/`,
`scripts/`, `Makefile`, CI e docs. Mudancas de codigo de aplicacao vao nos
repositorios de cada componente.

## Alterando um componente

Fluxo completo (setup de forks, apontar submodulos, bump de ponteiro, merge do
fork do Platform para o central) esta no **README, secao
"Fluxo de forks e Pull Requests"**. Resumo:

1. `./scripts/use-fork.sh <seu-usuario>` + `git submodule update --remote --init`
   (muda so o `.git/config` local; `.gitmodules` continua em `fga-eps-mds/*`).
2. `cd MeasureSoftGram-<Componente>`, branch a partir de `develop`, commit, push
   para o seu fork; PR com base `fga-eps-mds/MeasureSoftGram-<Componente>` `develop`.
3. Apos o merge: `./scripts/use-fork.sh --reset && git submodule update --remote`,
   branch no seu fork do Platform, `git add MeasureSoftGram-<Componente>`, commit,
   PR com base `fga-eps-mds/MeasureSoftGram-Platform` `develop`.
4. O CI `compose-smoke` valida o bump antes do merge (squash) no `develop`.

## Antes de abrir o PR

- `make clean && make setup` sobe do zero sem erro.
- `make smoke` passa (o CI `compose-smoke` roda o mesmo script).
- Commits no imperativo; PR descreve o "porque".

## Bump de submodulos

`make submodules-update` avanca todos para o topo de `develop`. Revise os
ponteiros e o smoke test antes de commitar.
