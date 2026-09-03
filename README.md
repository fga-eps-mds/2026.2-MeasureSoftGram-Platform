# MeasureSoftGram-Platform

Repositório guarda-chuva do **MeasureSoftGram**. Referencia os oito
repositórios do produto como **git submodules** e carrega o
`docker-compose.yml` que sobe a stack inteira — Front, API, Django admin,
Swagger e dashboards do Grafana — atrás de um **proxy nginx único** em
`http://localhost`, buildando a partir do código dos submódulos.

## Índice

- [Stack](#stack)
- [Pré-requisitos](#pré-requisitos)
- [Quick start](#quick-start)
- [URLs](#urls)
- [Credenciais do seed](#credenciais-do-seed)
- [Tokens que exigem ação manual externa](#tokens-que-exigem-ação-manual-externa)
- [Aplicar mudanças no `.env`](#aplicar-mudanças-no-env)
- [Variáveis (`.env`)](#variáveis-env)
- [MCP / AI](#mcp--ai)
- [Plugin do VS Code](#plugin-do-vs-code)
- [Fluxo de trabalho por semestre](#fluxo-de-trabalho-por-semestre)
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
                                           │
   clientes MCP  ─────────────────────►  ai (servidor MCP :8000)   [profile ai]
   http://localhost:8000/mcp               fala direto com service, fora do proxy
```

| Submódulo | Papel | Container |
|---|---|---|
| MeasureSoftGram-Service | API Django + DRF (`:8080`) | sim |
| MeasureSoftGram-Front | Next.js 12 (`:3000`) | sim |
| MeasureSoftGram-Core | lib `msgram_core` | não (usada pelo CLI) |
| MeasureSoftGram-Parser | lib `msgram-parser` | não (usada pelo CLI) |
| MeasureSoftGram-CLI | app `msgram` | profile `tools` |
| MeasureSoftGram-Action | GitHub Action | profile `tools` |
| MeasureSoftGram-Plugin | extensão de VS Code | profile `tools` |
| MeasureSoftGram-AI | servidor MCP (`:8000`) | profile `ai` |

## Pré-requisitos

- Docker Desktop com **Compose v2**
- git
- GNU Make (opcional — os alvos do `Makefile` são atalhos para `docker compose`;
  no Windows: `winget install ezwinports.make`, ou rode os comandos
  `docker compose --env-file .env ...` direto / via WSL)

## Quick start

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/MeasureSoftGram-Platform.git
cd MeasureSoftGram-Platform
cp .env.example .env      # preencha a seção "GitHub OAuth" (opcional p/ login local user/senha)
make setup                # submódulos -> build -> up -> smoke test
```

> **Aluno:** você clona o **fork do semestre vigente**
> (`<SEM>-MeasureSoftGram-Platform`, onde `<SEM>` é o semestre atual no padrão
> `AAAA.S` — ver
> [Fluxo de trabalho por semestre](#fluxo-de-trabalho-por-semestre)), não o
> central.

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
Preencha conforme o objetivo:

| Objetivo | Variáveis a preencher |
|---|---|
| Só ver o produto / login local | nenhuma |
| Login "Entrar com GitHub" | `GITHUB_CLIENT_ID`, `GITHUB_SECRET` |
| Coletar métricas de repos do GitHub | `GITHUB_TOKEN` |
| Rodar a Action (`make action-test`) | `MSGRAM_TOKEN`, `GITHUB_TOKEN` (+ `SONAR_TOKEN` se usar Sonar) |

Depois de editar o `.env`, aplique com o comando da seção
[Aplicar mudanças no `.env`](#aplicar-mudanças-no-env).

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

> `GITHUB_CLIENT_ID` e `LOGIN_REDIRECT_URL` são **build-time no Front**: exigem
> `build front` ao alterar (o comando abaixo já faz).
> Mudou `PROXY_PORT`? O callback vira `http://localhost:<porta>` nos três lugares:
> OAuth App, `LOGIN_REDIRECT_URL` e `PUBLIC_URL`.

### 2. `GITHUB_TOKEN` — coleta de métricas do GitHub

Um **Personal Access Token**. Sem ele o produto sobe normal; só a coleta de
métricas de repositórios do GitHub fica indisponível.

- **Clássico** (mais simples): https://github.com/settings/tokens >
  *Generate new token (classic)* > escopos **`repo`** e **`read:org`** > copiar `ghp_...`.
- **Fine-grained**: https://github.com/settings/tokens?type=beta > selecionar os
  repositórios > permissões de leitura em *Contents*, *Pull requests*, *Issues*, *Metadata*.

### 3. `MSGRAM_TOKEN` — token da API da plataforma (profile `tools` / Action)

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

## Aplicar mudanças no `.env`

```bash
# recomendado: rebuilda o Front (vars build-time) e recria service + front
docker compose --env-file .env up -d --build front service

# se só mexeu em vars de runtime (sem GITHUB_CLIENT_ID / NEXT_PUBLIC_* / LOGIN_REDIRECT_URL):
docker compose --env-file .env up -d service
```

Com `make`: `make build && make up`.

## Variáveis (`.env`)

Fonte única de configuração. Principais:

| Variável | Default | Nota |
|---|---|---|
| `PROXY_PORT` | `80` | mude se a :80 estiver ocupada |
| `PUBLIC_URL` | `http://localhost` | inclua a porta se mudar `PROXY_PORT` |
| `DJANGO_SETTINGS_MODULE` | `config.settings.dev` | `config.settings.production` p/ prod |
| `SECRET_KEY` | preenchida | vazia => chave aleatória por worker => sessões quebram |
| `CREATE_FAKE_DATA` | `TRUE` | cria dados fake + `admin/admin` |
| `NEXT_PUBLIC_API_URL` | `http://localhost/api` | **build-time**, sem `/v1` |
| `GRAFANA_PASSWORD` | `admin123` | vira `GF_SECURITY_ADMIN_PASSWORD` |
| `MCP_PORT` | `8000` | porta publicada do servidor MCP (profile `ai`) |
| `MCP_TRANSPORT` | `streamable-http` | transporte do FastMCP |
| `MSGRAM_USER` / `MSGRAM_PASSWORD` | `admin` / `admin` | credenciais que o MCP usa na API do Service |

Lista completa comentada em [`.env.example`](.env.example).

## MCP / AI

`MeasureSoftGram-AI` é um **servidor MCP** (Model Context Protocol) que expõe os
dados do Service — organizações, produtos, métricas, releases, matriz de
balanço, valores históricos — como ferramentas para LLMs.

```bash
make ai-up            # builda o AI e sobe (profile ai); precisa do service healthy
make ai-logs          # acompanha o servidor MCP
```

- Endpoint: `http://localhost:8000/mcp` (transporte `streamable-http`).
- **Não** passa pelo proxy nginx — clientes MCP falam direto com a porta 8000.
- **Não** sobe no `make up` padrão (evita somar tempo de build a quem só quer
  abrir `http://localhost`).

Para plugar num cliente MCP (Claude Desktop, etc.), configure um servidor HTTP
apontando para `http://localhost:8000/mcp`. Para testar sem cliente real, o
**MCP Inspector** sobe junto no profile `ai` em `http://localhost:6274` — ele
lista as tools e permite chamá-las (ex.: listar organizações retorna os dados do
seed).

## Plugin do VS Code

`MeasureSoftGram-Plugin` é uma **extensão de VS Code** (TypeScript) que mostra o
TSQMI e dashboards do Grafana dentro do editor, consumindo a API do Service.
Não roda como serviço da stack.

Para desenvolver:

1. Abra `MeasureSoftGram-Plugin/` no VS Code.
2. `npm install` (ou, sem Node local: `make plugin ARGS="npm install"`).
3. **F5** para abrir a *Extension Development Host*.
4. Aponte a extensão para a stack local: `http://localhost/api`.

O container `plugin` (profile `tools`, imagem `node:20`) serve para
`npm install` / testes / empacotar o `.vsix` sem exigir Node na máquina:

```bash
make plugin ARGS="npm install"
make plugin ARGS="npm test"
```

## Fluxo de trabalho por semestre

O trabalho da disciplina é **por semestre**, não por contribuidor avulso.

> ### O número do semestre (`<SEM>`)
>
> `<SEM>` **não é um valor fixo** — é o semestre **corrente**, no padrão
> **`AAAA.S`**: quatro dígitos de ano, ponto, `1` ou `2`. Ele **avança a cada
> semestre**:
>
> ```
> ... → 2026.2 → 2027.1 → 2027.2 → 2028.1 → 2028.2 → ...
> ```
>
> Onde este documento escreve `<SEM>` (ou `<SEM>-MeasureSoftGram-Platform`,
> `S=<SEM>` etc.), **troque pelo semestre em que você está**. Não há nenhum
> semestre "padrão" embutido no repo.

**Três níveis:**

| Nível | Onde | Papel |
|---|---|---|
| **Central** | `fga-eps-mds/MeasureSoftGram-X` | protegido; recebe o merge no fim do semestre |
| **Fork de semestre** | `fga-eps-mds/<SEM>-MeasureSoftGram-X` | onde a equipe trabalha o semestre inteiro |
| **Branch de feature** | dentro do fork de semestre | uma mudança; PR **dentro do próprio fork** |

O prefixo `<SEM>-` existe só porque o GitHub não aceita dois repos de mesmo nome
no mesmo dono. **Não há fork pessoal.**

```
  fga-eps-mds/MeasureSoftGram-Service ... (x8 componentes)  ◄──┐ (2) merge no fim
  fga-eps-mds/MeasureSoftGram-Platform                      ◄─┐│    do semestre
        │ .gitmodules -> fga-eps-mds/*                        ││
        │  (fork = mesmo repo, .gitmodules reescrito)         ││
        ▼                                                     ││
  fga-eps-mds/<SEM>-MeasureSoftGram-Service ... (x8)  ────────┘│
  fga-eps-mds/<SEM>-MeasureSoftGram-Platform  ─────────────────┘
        │ .gitmodules -> fga-eps-mds/<SEM>-*  (commitado)
        ▼
  branch de feature  ──► PR dentro do <SEM>-MeasureSoftGram-*
```

### Setup do semestre (uma vez, pela equipe)

`<SEM>` abaixo é o semestre vigente no padrão `AAAA.S` (o de então — p. ex., no
segundo semestre de 2027 seria `2027.2`).

1. Forke os **9 repos** na própria org `fga-eps-mds`, renomeando para
   `<SEM>-MeasureSoftGram-*`.
2. No fork do Platform:

   ```bash
   git clone --recurse-submodules https://github.com/fga-eps-mds/<SEM>-MeasureSoftGram-Platform.git
   cd <SEM>-MeasureSoftGram-Platform
   ./scripts/semester.sh use <SEM>       # 1º arg = semestre AAAA.S; reescreve .gitmodules
   git add .gitmodules && git commit -m "chore: aponta submódulos para <SEM>-*"
   git push
   ```

   **Esse commit é a única diferença estrutural** entre o fork de semestre e o
   central. O **`path` de cada submódulo nunca muda** (continua
   `MeasureSoftGram-Service` etc.) — só a URL. `docker-compose.yml`,
   `docker/cli/Dockerfile` e `nginx/` dependem desses paths.

### Setup de cada dev

Clone o fork do **semestre vigente** (`<SEM>` = `AAAA.S`, o semestre atual):

```bash
git clone --recurse-submodules https://github.com/fga-eps-mds/<SEM>-MeasureSoftGram-Platform.git
cd <SEM>-MeasureSoftGram-Platform
cp .env.example .env
make setup
```

Nada de "apontar submódulos" — o `.gitmodules` do fork já resolve.

### Mudar um componente

```bash
cd MeasureSoftGram-Service
git checkout develop && git pull
git checkout -b feat/minha-mudanca
# ... código, commits ...
git push origin feat/minha-mudanca        # origin = <SEM>-MeasureSoftGram-Service
```

Abra o PR **dentro do próprio `<SEM>-MeasureSoftGram-Service`** (base:
`develop`). Teste local subindo a stack (`docker compose up -d --build`).

### Bump de ponteiro do submódulo no Platform

Depois que o PR do componente for mergeado no `develop` do fork de semestre:

```bash
make submodules-update            # avança todos para o topo de develop
git add MeasureSoftGram-*
git commit -m "chore: bump submódulos"
git push origin chore/bump
```

PR no `<SEM>-MeasureSoftGram-Platform`; o CI `compose-smoke` valida.

### Entrega: merge do semestre → central

A parte mais delicada. Um submódulo grava **URL** (`.gitmodules`) **e commit**
(ponteiro): no fork de semestre os dois divergem do central. O merge **não pode
ser cru** — precisa de promoção, **nesta ordem**:

1. **PR de cada `<SEM>-MeasureSoftGram-X` → `X` central** (`develop`). Só depois
   disso os commits apontados passam a existir no central.
2. **Só então, no Platform:**

   ```bash
   ./scripts/semester.sh reset          # .gitmodules -> fga-eps-mds/* (central)
   ./scripts/promote-to-central.sh      # confere ancestralidade + avança ponteiros
   ```

   Revise que o diff contém o `.gitmodules` voltando para `fga-eps-mds/*` **e**
   os ponteiros re-apontados. Commite e abra o **PR
   `<SEM>-MeasureSoftGram-Platform` → central**.

> **Inverter a ordem gera ponteiros quebrados no central** — o Platform central
> passaria a referenciar commits que só existem nos forks de semestre (`<SEM>-*`)
> (`fatal: remote error: upload-pack: not our ref`).

### Semestre seguinte

No começo de cada semestre, forke de novo a partir do central **já atualizado**,
usando o novo `<SEM>` (a sequência é `... → 2026.2 → 2027.1 → 2027.2 → 2028.1 →
...`). Os forks dos semestres anteriores ficam como histórico, não são
reaproveitados.

## Comandos úteis

```bash
make up / down / restart / clean     # clean também apaga volumes
make up-min                          # sem Grafana
make logs S=service                  # logs de um serviço
make smoke                           # smoke test
make seed / migrate / superuser
make grant-access USER=admin         # vê os dados fake logando com admin/admin
make cli ARGS="init"                 # roda o CLI (profile tools)
make action-test                     # replaya os workflows do Action com act
make test-service / test-front

make ai-up / ai-logs                 # servidor MCP (profile ai)
make plugin ARGS="npm install"       # container do Plugin (profile tools)

make semester S=<AAAA.S>             # aponta .gitmodules para o fork do semestre (ex.: S=2026.2)
make semester-status                 # URL efetiva de cada submódulo + semestre
make promote                         # promove os submódulos do semestre -> central
make submodules-update               # avança os submódulos para o topo de develop
```

## Troubleshooting

- **Porta 80 ocupada no Windows** (IIS / "World Wide Web Publishing Service"):
  no `.env` ajuste **em conjunto** —
  `PROXY_PORT=8081`, `PUBLIC_URL=http://localhost:8081`,
  `NEXT_PUBLIC_API_URL=http://localhost:8081/api`,
  `LOGIN_REDIRECT_URL=http://localhost:8081` e o callback do OAuth App.
  Depois `make build && make up`.
- **Mudei `NEXT_PUBLIC_*` e não surtiu efeito**: são inlined no bundle;
  `docker compose build front`.
- **Build do Front lento**: normal na primeira vez (`pnpm build` de produção).
- **`/products/` (ou `/organizations/`) vazio ou com erro / `github-organizations`
  400**: o backend só mostra org/produto para quem é **membro da organização**.
  Os dados fake do seed pertencem a `SEED_GITHUB_USERNAME` (default `msgramteste`).
  - logando com **`admin`/`admin`**: `./scripts/grant-access.sh admin`
    (`make grant-access USER=admin`) te adiciona a todas as orgs.
  - logando com **GitHub**: ponha seu login em `SEED_GITHUB_USERNAME` no `.env`,
    `docker compose --env-file .env up -d service` e
    `docker compose --env-file .env exec service python manage.py load_initial_data`;
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
- **Submódulo em commit que não existe** (`fatal: remote error: upload-pack: not
  our ref` no `git submodule update`): o ponteiro aponta para um commit de um
  fork de semestre (`<SEM>-*`) mas o `.gitmodules` está apontando para o central
  (ou vice-versa).
  Rode `./scripts/semester.sh status` para ver o descompasso; na entrega, siga a
  ordem de merge (componentes → central **antes** do Platform).
- **MCP não conecta** (`curl http://localhost:8000/mcp` recusa conexão): o
  `service` precisa estar **healthy** antes do `ai` subir; e o profile `ai` **não
  sobe** no `make up` padrão — rode `make ai-up`.
- **O serviço de banco não pode ser renomeado**: o datasource do Grafana
  (`MeasureSoftGram-Service/grafana/provisioning/datasources/measuresoftgram.yml`)
  tem `url: db:5432` hardcoded.

## Notas

- Nenhum arquivo dos submódulos é modificado por este repo — ele só lê os
  `Dockerfile`s e `grafana/{provisioning,dashboards}` do Service.
- Não há Redis/Celery: o agendamento é `django-apscheduler` in-process com
  advisory lock no Postgres.
