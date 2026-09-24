# MeasureSoftGram-Platform

Repositório guarda-chuva do **MeasureSoftGram**. Referencia os nove
repositórios do produto como **git submodules** e carrega o
`docker-compose.yml` que sobe a stack — Front, API, Django admin, Swagger,
dashboards do Grafana e documentação — atrás de um **proxy nginx único** em
`http://localhost`, buildando a partir do código dos submódulos.

Tudo sobe em **modo desenvolvimento**, com **hot reload**: editou o código de
um submódulo, o serviço correspondente recarrega sozinho, sem rebuild.

## Índice

- [Stack](#stack)
- [Pré-requisitos](#pré-requisitos)
- [Quick start](#quick-start)
- [Escolhendo os serviços](#escolhendo-os-serviços)
- [Desenvolvendo com hot reload](#desenvolvendo-com-hot-reload)
- [URLs](#urls)
- [Credenciais do seed](#credenciais-do-seed)
- [Tokens que exigem ação manual externa](#tokens-que-exigem-ação-manual-externa)
- [Variáveis (`.env`)](#variáveis-env)
- [CLI, Action e Plugin](#cli-action-e-plugin)
- [Comandos úteis](#comandos-úteis)
- [Troubleshooting](#troubleshooting)
- [Notas](#notas)

## Stack

```
                    ┌─────────── proxy (nginx :80) ───────────┐
                    │   /            -> front  (Next.js :3000) │
   http://localhost │   /api /swagger /admin /static -> service (Django :8080)
                    │   /grafana     -> grafana (:3000)        │
                    └──────────────────────┬──────────────────┘
                                           │
                                     db (postgres:18)

   http://localhost:3001  ─────────────►  docs (Docusaurus)     [profile docs]
   http://localhost:8000/mcp ───────────►  ai (servidor MCP)     [profile ai]
```

| Submódulo | Papel | Sobe como |
|---|---|---|
| MeasureSoftGram-Service | API Django + DRF (`:8080`) | serviço, hot reload |
| MeasureSoftGram-Front | Next.js 12 (`:3000`) | serviço, hot reload |
| MeasureSoftGram-Core | lib `msgram_core` | usada pelo CLI |
| MeasureSoftGram-Parser | lib `msgram-parser` | usada pelo CLI |
| MeasureSoftGram-CLI | app `msgram` | `make cli` |
| MeasureSoftGram-Action | GitHub Action | `make action-test` |
| MeasureSoftGram-Plugin | extensão de VS Code | dev local (F5) |
| MeasureSoftGram-AI | servidor MCP (`:8000`) | serviço, hot reload |
| MeasureSoftGram-DOC | site de documentação (Docusaurus, `:3001`) | serviço, hot reload |

## Pré-requisitos

- Docker Desktop com **Compose v2**
- git
- GNU Make (opcional — os alvos do `Makefile` são atalhos para `docker
  compose`; no Windows: `winget install ezwinports.make`, ou rode os
  comandos `docker compose ...` direto / via WSL)

## Quick start

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/2026.2-MeasureSoftGram-Platform.git
cd 2026.2-MeasureSoftGram-Platform
cp .env.example .env      # preencha a seção "GitHub OAuth" (opcional p/ login local user/senha)
make select                # escolhe o que sobe (ou edite COMPOSE_PROFILES no .env)
make up
```

Sem `make`:

```bash
git submodule update --init --recursive
cp .env.example .env
docker compose up -d --build
```

> Primeiro build leva alguns minutos (instala as dependências de cada
> serviço). Depois disso o hot reload é rápido.

Abra `http://localhost`.

## Escolhendo os serviços

Você não precisa subir a stack inteira. A variável `COMPOSE_PROFILES` do
`.env` decide o que `docker compose up -d` sobe — edite-a direto ou rode
`make select` para um menu interativo:

```
==> Servicos (numero p/ marcar/desmarcar, Enter p/ salvar):
  1) [x] service  API Django (hot reload)
  2) [x] front    Next.js — Front (hot reload)
  3) [x] grafana  Dashboards Grafana
  4) [ ] ai       Servidor MCP / AI (hot reload)
  5) [ ] docs     Documentacao Docusaurus (hot reload)
```

| Profile | Sobe junto | URL | Hot reload |
|---|---|---|---|
| `service` | db, proxy | http://localhost/api/v1/ | sim |
| `front` | service, db, proxy | http://localhost | sim |
| `grafana` | db, proxy | http://localhost/grafana/ | — |
| `ai` | service, db | http://localhost:8000/mcp | sim |
| `docs` | — | http://localhost:3001 | sim |

Marcar `front` já traz `service`, `db` e `proxy` junto (Front depende de
Service). `docs` é independente — sobe sozinho, sem banco.

`cli`, `action` e `plugin` não fazem parte de `COMPOSE_PROFILES`: são
containers utilitários, chamados sob demanda (`make cli ARGS=...`, `make
action-test`, `make plugin ARGS=...`).

## Desenvolvendo com hot reload

Edite o código dentro do submódulo normalmente (`MeasureSoftGram-Service/src`,
`MeasureSoftGram-Front/src`, `MeasureSoftGram-AI/src`,
`MeasureSoftGram-DOC/docs`, `MeasureSoftGram-Core`,
`MeasureSoftGram-Parser`, `MeasureSoftGram-CLI`) e o container correspondente
recarrega sozinho:

| Submódulo | Como recarrega |
|---|---|
| Service | `manage.py runserver` (reload nativo do Django) observa `src/` |
| Front | `next dev` recompila e atualiza o browser (HMR) |
| AI | `watchfiles` reinicia o servidor MCP |
| DOC | `docusaurus start` recarrega a página no browser |
| Core / Parser / CLI | instalados em modo editável (`pip install -e`) no
  container `cli`; mudança vale na próxima chamada, sem rebuild |

Quando **não** basta salvar o arquivo:

- Mudou dependências (`pyproject.toml`, `uv.lock`, `package.json`,
  `pnpm-lock.yaml`): `docker compose up -d --build <serviço>`.
- Mudou variável de ambiente no `.env`: `docker compose up -d <serviço>`
  (recria o container; não precisa rebuild).
- Plugin do VS Code: não roda dentro da stack — veja
  [CLI, Action e Plugin](#cli-action-e-plugin).

## URLs

| O que | URL |
|---|---|
| Front | http://localhost |
| API / DRF | http://localhost/api/v1/ |
| Swagger | http://localhost/swagger/ |
| Django admin | http://localhost/admin/ |
| Grafana | http://localhost/grafana/ |
| Documentação (profile `docs`) | http://localhost:3001 |
| Servidor MCP (profile `ai`) | http://localhost:8000/mcp |
| MCP Inspector (profile `ai`) | http://localhost:6274 |

## Credenciais do seed

Com `CREATE_FAKE_DATA=TRUE` (default), o `load_initial_data` cria orgs/produtos
fake e um superusuário:

| Sistema | Usuário | Senha |
|---|---|---|
| Django admin | `admin` | `admin` |
| Grafana | `admin` | `admin123` (`GRAFANA_PASSWORD`) |

## Tokens que exigem ação manual externa

Nenhum é necessário para abrir `http://localhost` e logar com `admin`/`admin`.
Preencha no `.env` conforme o objetivo, depois `docker compose up -d service
front` para aplicar:

| Objetivo | Variáveis a preencher |
|---|---|
| Só ver o produto / login local | nenhuma |
| Login "Entrar com GitHub" | `GITHUB_CLIENT_ID`, `GITHUB_SECRET` |
| Coletar métricas de repos do GitHub | `GITHUB_TOKEN` |
| Rodar a Action (`make action-test`) | `MSGRAM_TOKEN`, `GITHUB_TOKEN` (+ `SONAR_TOKEN` se usar Sonar) |

### 1. `GITHUB_CLIENT_ID` e `GITHUB_SECRET` — login por GitHub

Vêm de um **GitHub OAuth App**.

1. Abra https://github.com/settings/developers > **New OAuth App**
   (ou, numa organização: `https://github.com/organizations/<ORG>/settings/applications`).
2. Preencha:

   | Campo | Valor |
   |---|---|
   | Application name | `MeasureSoftGram local` (livre) |
   | Homepage URL | `http://localhost` |
   | Authorization callback URL | `http://localhost` — **idêntico** a `LOGIN_REDIRECT_URL` do `.env` |

3. **Register application**.
4. Copie o **Client ID** para `GITHUB_CLIENT_ID`.
5. **Generate a new client secret**, copie (só aparece uma vez) para `GITHUB_SECRET`.

> Mudou `PROXY_PORT`? O callback vira `http://localhost:<porta>` nos três
> lugares: OAuth App, `LOGIN_REDIRECT_URL` e `PUBLIC_URL`.

### 2. `GITHUB_TOKEN` — coleta de métricas do GitHub

Um **Personal Access Token**. Sem ele o produto sobe normal; só a coleta de
métricas de repositórios do GitHub fica indisponível.

- **Clássico** (mais simples): https://github.com/settings/tokens >
  *Generate new token (classic)* > escopos **`repo`** e **`read:org`** > copiar `ghp_...`.
- **Fine-grained**: https://github.com/settings/tokens?type=beta > selecionar os
  repositórios > permissões de leitura em *Contents*, *Pull requests*, *Issues*, *Metadata*.

### 3. `MSGRAM_TOKEN` — token da API da plataforma (Action)

Token de autenticação DRF do seu usuário. Com a stack no ar:

```bash
curl -s -X POST http://localhost/api/v1/accounts/login/ \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin"}'
# {"key":"<TOKEN>"}   <- cole o valor de "key" em MSGRAM_TOKEN
```

Alternativas: `GET http://localhost/api/v1/accounts/access-token/` (já logado no
Front) ou `http://localhost/admin/authtoken/tokenproxy/` no Django admin.

### 4. `SONAR_TOKEN` — métricas do SonarQube/SonarCloud (opcional, só Action)

- SonarCloud: https://sonarcloud.io > *My Account* > **Security** > *Generate Token*.
- SonarQube self-hosted: *My Account* > *Security* > *Generate Token*.

## Variáveis (`.env`)

Fonte única de configuração. Principais:

| Variável | Default | Nota |
|---|---|---|
| `COMPOSE_PROFILES` | `service,front,grafana` | o que sobe com `docker compose up -d` — veja [Escolhendo os serviços](#escolhendo-os-serviços) |
| `PROXY_PORT` | `80` | mude se a :80 estiver ocupada |
| `PUBLIC_URL` | `http://localhost` | inclua a porta se mudar `PROXY_PORT` |
| `SECRET_KEY` | preenchida | vazia => chave aleatória por worker => sessões quebram |
| `CREATE_FAKE_DATA` | `TRUE` | cria dados fake + `admin/admin` |
| `NEXT_PUBLIC_API_URL` | `http://localhost/api` | sem `/v1`; lida em runtime pelo `next dev` |
| `GRAFANA_PASSWORD` | `admin123` | vira `GF_SECURITY_ADMIN_PASSWORD` |
| `MCP_PORT` / `DOCS_PORT` | `8000` / `3001` | portas publicadas dos profiles `ai` / `docs` |
| `MSGRAM_USER` / `MSGRAM_PASSWORD` | `admin` / `admin` | credenciais que o MCP usa na API do Service |

Lista completa comentada em [`.env.example`](.env.example).

## CLI, Action e Plugin

Não são serviços da stack — são containers utilitários chamados sob demanda:

```bash
make cli ARGS="init"                 # roda o CLI (msgram)
make action-test                     # replaya os workflows do Action com act
make plugin ARGS="npm install"       # container do Plugin (npm install/test/build)
```

Core e Parser são instalados em modo editável dentro do container `cli`
(`./MeasureSoftGram-Core`, `./MeasureSoftGram-Parser`, `./MeasureSoftGram-CLI`
montados por cima da imagem) — editar o código deles vale na próxima chamada,
sem rebuild.

O **Plugin de VS Code** roda fora do Docker, com hot reload próprio do editor:

1. Abra `MeasureSoftGram-Plugin/` no VS Code.
2. `npm install` (ou `make plugin ARGS="npm install"`).
3. `npm run watch` (recompila TypeScript a cada save) e **F5** para abrir a
   *Extension Development Host*.
4. Aponte a extensão para a stack local: `http://localhost/api`.

## Comandos úteis

```bash
make select                          # escolhe os servicos (grava COMPOSE_PROFILES)
make up / down / restart / clean     # clean tambem apaga volumes
make logs S=service                  # logs de um servico
make smoke                           # smoke test
make seed / migrate / superuser
make grant-access USER=admin         # ve os dados fake logando com admin/admin
make cli ARGS="init"                 # roda o CLI
make action-test                     # replaya os workflows do Action com act
make plugin ARGS="npm install"       # container do Plugin
make test-service / test-front
```

## Troubleshooting

- **Porta 80 ocupada no Windows** (IIS / "World Wide Web Publishing Service"):
  no `.env` ajuste **em conjunto** —
  `PROXY_PORT=8081`, `PUBLIC_URL=http://localhost:8081`,
  `NEXT_PUBLIC_API_URL=http://localhost:8081/api`,
  `LOGIN_REDIRECT_URL=http://localhost:8081` e o callback do OAuth App.
  Depois `make up`.
- **Front lento na primeira página**: normal — `next dev` compila a rota na
  primeira request (diferente de um build de produção). As próximas são
  rápidas.
- **Hot reload não pega uma mudança**: em alguns hosts (Windows/mac) bind
  mounts não propagam eventos de filesystem; Service/AI/DOC já rodam em modo
  *polling* para cobrir isso. Se ainda assim não recarregar, reinicie o
  serviço (`docker compose restart <serviço>`).
- **`/products/` (ou `/organizations/`) vazio ou com erro / `github-organizations`
  400**: o backend só mostra org/produto para quem é **membro da organização**.
  Os dados fake do seed pertencem a `SEED_GITHUB_USERNAME` (default `msgramteste`).
  - logando com **`admin`/`admin`**: `./scripts/grant-access.sh admin`
    (`make grant-access USER=admin`) te adiciona a todas as orgs.
  - logando com **GitHub**: ponha seu login em `SEED_GITHUB_USERNAME` no `.env`,
    `docker compose up -d service` e
    `docker compose exec service python manage.py load_initial_data`;
    ou rode `./scripts/grant-access.sh <seu-login-github>` depois do primeiro login.
- **`github-organizations` (ou repos do GitHub) sempre 400 `GitHub account not
  linked or access token missing`, mesmo logado via GitHub**: esta versão do
  Service roda `django-allauth` com `SOCIALACCOUNT_STORE_TOKENS=False` — ao
  "Entrar com GitHub" a conta é vinculada mas **o access token do OAuth não é
  persistido**. Esses endpoints leem `CustomUser.github_access_token`, que fica
  vazio. Workaround até o Service corrigir (ligar `STORE_TOKENS` + `SocialApp` no
  banco): gravar um PAT no perfil do usuário logado —

  ```bash
  ./scripts/set-github-token.sh <username>       # usa GITHUB_TOKEN do .env
  # make set-github-token USER=<username>
  ```

  O `<username>` é o login do GitHub de quem entrou (ex.: `zzzBECK`), ou `admin`
  se estiver no login local. Não é `GITHUB_TOKEN` do `.env` que resolve — ele é
  só para coleta de métricas no backend.
- **MCP não conecta** (`curl http://localhost:8000/mcp` recusa conexão): o
  `service` precisa estar **healthy** antes do `ai` subir; confira se o
  profile `ai` está marcado (`make select` ou `COMPOSE_PROFILES` no `.env`).
- **O serviço de banco não pode ser renomeado**: o datasource do Grafana
  (`MeasureSoftGram-Service/grafana/provisioning/datasources/measuresoftgram.yml`)
  tem `url: db:5432` hardcoded.

## Notas

- Nenhum arquivo dos submódulos é modificado por este repo — ele só lê os
  `Dockerfile.dev` e `grafana/{provisioning,dashboards}` do Service, e
  monta o código dos demais submódulos por cima de imagens base para dev.
- Não há Redis/Celery: o agendamento é `django-apscheduler` in-process com
  advisory lock no Postgres.
