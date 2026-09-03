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

## Tokens que exigem acao manual externa

Nenhum e necessario para abrir `http://localhost` e logar com `admin`/`admin`.
Preencha conforme o objetivo:

| Objetivo | Variaveis a preencher |
|---|---|
| So ver o produto / login local | nenhuma |
| Login "Entrar com GitHub" | `GITHUB_CLIENT_ID`, `GITHUB_SECRET` |
| Coletar metricas de repos do GitHub | `GITHUB_TOKEN` |
| Rodar a Action (`make action-test`) | `MSGRAM_TOKEN`, `GITHUB_TOKEN` (+ `SONAR_TOKEN` se usar Sonar) |

Depois de editar o `.env`, aplique com o comando da secao
[Aplicar mudancas no `.env`](#aplicar-mudancas-no-env).

### 1. `GITHUB_CLIENT_ID` e `GITHUB_SECRET` — login por GitHub

Vem de um **GitHub OAuth App**.

1. Abra https://github.com/settings/developers > **New OAuth App**
   (ou, numa organizacao: `https://github.com/organizations/<ORG>/settings/applications`).
2. Preencha:

   | Campo | Valor |
   |---|---|
   | Application name | `MeasureSoftGram local` (livre) |
   | Homepage URL | `http://localhost` |
   | Authorization callback URL | `http://localhost` — **identico** a `LOGIN_REDIRECT_URL` do `.env` |

3. **Register application**.
4. Copie o **Client ID** para `GITHUB_CLIENT_ID`.
5. **Generate a new client secret**, copie (so aparece uma vez) para `GITHUB_SECRET`.

> `GITHUB_CLIENT_ID` e `LOGIN_REDIRECT_URL` sao **build-time no Front**: exigem
> `build front` ao alterar (o comando abaixo ja faz).
> Mudou `PROXY_PORT`? O callback vira `http://localhost:<porta>` nos tres lugares:
> OAuth App, `LOGIN_REDIRECT_URL` e `PUBLIC_URL`.

### 2. `GITHUB_TOKEN` — coleta de metricas do GitHub

Um **Personal Access Token**. Sem ele o produto sobe normal; so a coleta de
metricas de repositorios do GitHub fica indisponivel.

- **Classico** (mais simples): https://github.com/settings/tokens >
  *Generate new token (classic)* > escopos **`repo`** e **`read:org`** > copiar `ghp_...`.
- **Fine-grained**: https://github.com/settings/tokens?type=beta > selecionar os
  repositorios > permissoes de leitura em *Contents*, *Pull requests*, *Issues*, *Metadata*.

### 3. `MSGRAM_TOKEN` — token da API da plataforma (profile `tools` / Action)

Token de autenticacao DRF do seu usuario. Com a stack no ar:

```bash
curl -s -X POST http://localhost/api/v1/accounts/login/ \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin"}'
# {"key":"<TOKEN>"}   <- cole o valor de "key" em MSGRAM_TOKEN
```

Alternativas: `GET http://localhost/api/v1/accounts/access-token/` (ja logado no
Front) ou `http://localhost/admin/authtoken/tokenproxy/` no Django admin.

### 4. `SONAR_TOKEN` — metricas do SonarQube/SonarCloud (opcional, so Action)

- SonarCloud: https://sonarcloud.io > *My Account* > **Security** > *Generate Token*.
- SonarQube self-hosted: *My Account* > *Security* > *Generate Token*.

## Aplicar mudancas no `.env`

```bash
# recomendado: rebuilda o Front (vars build-time) e recria service + front
docker compose --env-file .env up -d --build front service

# se so mexeu em vars de runtime (sem GITHUB_CLIENT_ID / NEXT_PUBLIC_* / LOGIN_REDIRECT_URL):
docker compose --env-file .env up -d service
```

Com `make`: `make build && make up`.

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
