# Contribuindo com o MeasureSoftGram-Platform

Este repo segue o mesmo fluxo de governança dos demais repositórios do
MeasureSoftGram: **trabalho por semestre**. A cada semestre a equipe forka os 9
repos na própria org com o prefixo do semestre no padrão **`AAAA.S`**
(`fga-eps-mds/<SEM>-MeasureSoftGram-*` — ex.: `2026.2-MeasureSoftGram-*`, e esse
número muda a cada semestre) e trabalha o semestre inteiro só no fork — branch →
Pull Request **dentro do próprio fork de semestre**. Ao final, merge do fork de
semestre → central.

Detalhes completos no **README, seção "Fluxo de trabalho por semestre"**.

## Setup de desenvolvimento

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/2026.2-MeasureSoftGram-Platform.git
cd 2026.2-MeasureSoftGram-Platform
cp .env.example .env
make setup
```

O `.gitmodules` do fork de semestre já aponta para os `2026.2-*` — não há passo
de "apontar submódulos".

## O que vive aqui

Somente a **orquestracao**: `docker-compose.yml`, `nginx/`, `docker/cli/`,
`scripts/`, `Makefile`, CI e docs. Mudancas de codigo de aplicacao vao nos
repositorios de cada componente.

## Alterando um componente

Fluxo completo (setup do semestre, bump de ponteiro, merge do fork de semestre
para o central) está no **README, seção "Fluxo de trabalho por semestre"**.
Resumo:

1. `cd MeasureSoftGram-<Componente>`, branch a partir de `develop`, commit, push
   para `origin` (= `2026.2-MeasureSoftGram-<Componente>`); PR **dentro do
   próprio fork de semestre**.
2. Após o merge: `make submodules-update`, branch no fork de semestre do
   Platform, `git add MeasureSoftGram-<Componente>`, commit, PR no
   `2026.2-MeasureSoftGram-Platform`.
3. O CI `compose-smoke` valida o bump antes do merge (squash) no `develop`.
4. Na entrega, promoção fork de semestre → central: veja o README
   (`./scripts/semester.sh reset` + `./scripts/promote-to-central.sh`, na ordem
   correta).

## Antes de abrir o PR

- `make clean && make setup` sobe do zero sem erro.
- `make smoke` passa (o CI `compose-smoke` roda o mesmo script).
- Commits no imperativo; PR descreve o "porque".

## Bump de submodulos

`make submodules-update` avanca todos para o topo de `develop`. Revise os
ponteiros e o smoke test antes de commitar.
