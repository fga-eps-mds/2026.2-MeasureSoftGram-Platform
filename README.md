# MeasureSoftGram-Platform

Repositorio guarda-chuva do **MeasureSoftGram**. Referencia os seis
repositorios do produto como **git submodules** e carrega o
`docker-compose.yml` que sobe a stack inteira — Front, API, Django admin,
Swagger e dashboards do Grafana — atras de um **proxy nginx unico** em
`http://localhost`, buildando a partir do codigo dos submodulos.

## Stack

```
                    ┌─────────── proxy (nginx :80) ───────────┐
                    │   /            -> front  (Next.js :3000) │
   http://localhost │   /api /swagger /admin /static -> service (Django :8080)
                    │   /grafana     -> grafana (:3000)        │
                    └──────────────────────┬──────────────────┘
                                           │
                                     db (postgres:18)
```

| Submodulo | Papel | Container |
|---|---|---|
| MeasureSoftGram-Service | API Django + DRF (`:8080`) | sim |
| MeasureSoftGram-Front | Next.js 12 (`:3000`) | sim |
| MeasureSoftGram-Core | lib `msgram_core` | nao (usada pelo CLI) |
| MeasureSoftGram-Parser | lib `msgram-parser` | nao (usada pelo CLI) |
| MeasureSoftGram-CLI | app `msgram` | profile `tools` |
| MeasureSoftGram-Action | GitHub Action | profile `tools` |

## Pre-requisitos

- Docker Desktop com **Compose v2**
- git
- GNU Make (opcional — os alvos do `Makefile` sao atalhos para `docker compose`;
  no Windows: `winget install ezwinports.make`, ou rode os comandos
  `docker compose --env-file .env ...` direto / via WSL)

## Quick start

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/MeasureSoftGram-Platform.git
cd MeasureSoftGram-Platform
cp .env.example .env      # preencha a secao "GitHub OAuth" (opcional p/ login local user/senha)
make setup                # submodulos -> build -> up -> smoke test
```

Sem `make`:

```bash
git submodule update --init --recursive
cp .env.example .env
docker compose --env-file .env up -d --build
bash scripts/smoke-test.sh
```

> Primeiro build leva **~5-10 min** (uv sync do Service + `pnpm build` do Front).

Abra `http://localhost`.

## URLs

| O que | URL |
|---|---|
| Front | http://localhost |
| API / DRF | http://localhost/api/v1/ |
| Swagger | http://localhost/swagger/ |
| Django admin | http://localhost/admin/ |
| Grafana | http://localhost/grafana/ |

## Credenciais do seed

Com `CREATE_FAKE_DATA=TRUE` (default), o `load_initial_data` cria orgs/produtos
fake e um superusuario:

| Sistema | Usuario | Senha |
|---|---|---|
| Django admin | `admin` | `admin` |
| Grafana | `admin` | `admin123` (`GRAFANA_PASSWORD`) |

## GitHub OAuth App

O login "Entrar com GitHub" exige um OAuth App. Em
`https://github.com/settings/developers` > **New OAuth App**:

| Campo | Valor |
|---|---|
| Homepage URL | `http://localhost` |
| Authorization callback URL | `http://localhost` (identico a `LOGIN_REDIRECT_URL`) |

Copie **Client ID** e **Client secret** para o `.env`:

```bash
LOGIN_REDIRECT_URL=http://localhost
GITHUB_CLIENT_ID=<client id>
GITHUB_SECRET=<client secret>
GITHUB_TOKEN=<PAT com repo, read:org>
```

`GITHUB_CLIENT_ID` e `LOGIN_REDIRECT_URL` sao **build-time no Front** — depois de
alterar, `docker compose build front` (ou `make build`).

## Variaveis (`.env`)

Fonte unica de configuracao. Principais:

| Variavel | Default | Nota |
|---|---|---|
| `PROXY_PORT` | `80` | mude se a :80 estiver ocupada |
| `PUBLIC_URL` | `http://localhost` | inclua a porta se mudar `PROXY_PORT` |
| `DJANGO_SETTINGS_MODULE` | `config.settings.dev` | `config.settings.production` p/ prod |
| `SECRET_KEY` | preenchida | vazia => chave aleatoria por worker => sessoes quebram |
| `CREATE_FAKE_DATA` | `TRUE` | cria dados fake + `admin/admin` |
| `NEXT_PUBLIC_API_URL` | `http://localhost/api` | **build-time**, sem `/v1` |
| `GRAFANA_PASSWORD` | `admin123` | vira `GF_SECURITY_ADMIN_PASSWORD` |

Lista completa comentada em [`.env.example`](.env.example).

## Fluxo fork -> branch -> PR

Cada pessoa trabalha no proprio fork de cada repo e abre PR para
`fga-eps-mds/*`.

```bash
./scripts/use-fork.sh <seu-usuario>          # aponta os submodulos p/ seus forks
git submodule update --remote --init
cd MeasureSoftGram-Service
git checkout -b feature/minha-mudanca
# ... commits, push, PR para fga-eps-mds/MeasureSoftGram-Service ...
```

Para atualizar o ponteiro de um submodulo neste repo (num PR do Platform):

```bash
cd MeasureSoftGram-Service && git checkout develop && git pull
cd .. && git add MeasureSoftGram-Service && git commit -m "chore: bump Service"
```

`make submodules-update` faz isso para todos de uma vez.

Voltar aos repos centrais: `./scripts/use-fork.sh --reset`.

## Comandos uteis

```bash
make up / down / restart / clean     # clean tambem apaga volumes
make up-min                          # sem Grafana
make logs S=service                  # logs de um servico
make smoke                           # smoke test
make seed / migrate / superuser
make cli ARGS="init"                 # roda o CLI (profile tools)
make action-test                     # replaya os workflows do Action com act
make test-service / test-front
```

## Troubleshooting

- **Porta 80 ocupada no Windows** (IIS / "World Wide Web Publishing Service"):
  no `.env` ajuste **em conjunto** —
  `PROXY_PORT=8081`, `PUBLIC_URL=http://localhost:8081`,
  `NEXT_PUBLIC_API_URL=http://localhost:8081/api`,
  `LOGIN_REDIRECT_URL=http://localhost:8081` e o callback do OAuth App.
  Depois `make build && make up`.
- **Mudei `NEXT_PUBLIC_*` e nao surtiu efeito**: sao inlined no bundle;
  `docker compose build front`.
- **Build do Front lento**: normal na primeira vez (`pnpm build` de producao).
- **O servico de banco nao pode ser renomeado**: o datasource do Grafana
  (`MeasureSoftGram-Service/grafana/provisioning/datasources/measuresoftgram.yml`)
  tem `url: db:5432` hardcoded.

## Notas

- Nenhum arquivo dos seis submodulos e modificado por este repo — ele so le os
  `Dockerfile`s e `grafana/{provisioning,dashboards}` do Service.
- Nao ha Redis/Celery: o agendamento e `django-apscheduler` in-process com
  advisory lock no Postgres.
