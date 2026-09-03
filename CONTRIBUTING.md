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

1. `./scripts/use-fork.sh <seu-usuario>` e `git submodule update --remote --init`.
2. `cd MeasureSoftGram-<Componente>`, crie um branch, commit, push.
3. Abra PR para `fga-eps-mds/MeasureSoftGram-<Componente>`.
4. Depois do merge, abra um PR **aqui** avancando o ponteiro do submodulo
   (`git add MeasureSoftGram-<Componente> && git commit`).

## Antes de abrir o PR

- `make clean && make setup` sobe do zero sem erro.
- `make smoke` passa (o CI `compose-smoke` roda o mesmo script).
- Commits no imperativo; PR descreve o "porque".

## Bump de submodulos

`make submodules-update` avanca todos para o topo de `develop`. Revise os
ponteiros e o smoke test antes de commitar.
