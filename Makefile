SHELL := /bin/bash
DC := docker compose --env-file .env
COMPOSE_TOOLS := $(DC) --profile tools

.DEFAULT_GOAL := help
.PHONY: help setup up up-min down restart clean build rebuild logs ps smoke \
        seed grant-access set-github-token migrate superuser shell-service cli action-test \
        submodules-update semester semester-status promote ai-up ai-logs plugin \
        test-service test-front

help: ## Lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	 awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Bootstrap completo: submodulos -> .env -> build -> up -> smoke
	./scripts/bootstrap.sh

up: ## Sobe a stack padrao (db, service, front, grafana, proxy)
	$(DC) up -d

up-min: ## Sobe sem Grafana
	$(DC) up -d db service front proxy

down: ## Para a stack (mantem volumes)
	$(DC) down

restart: down up ## down + up

clean: ## Para a stack e APAGA volumes (dados do Postgres/Grafana)
	$(DC) down -v

build: ## Builda as imagens
	$(DC) build

rebuild: ## Builda sem cache
	$(DC) build --no-cache

logs: ## Logs (make logs S=service para um servico)
	$(DC) logs -f $(S)

ps: ## Status dos containers
	$(DC) ps

smoke: ## Roda o smoke test
	./scripts/smoke-test.sh

seed: ## Repopula dados iniciais + Grafana
	$(DC) exec service python manage.py load_initial_data
	$(DC) exec service python manage.py seed_grafana || true

grant-access: ## Da acesso a todas as orgs a um usuario: make grant-access USER=admin
	./scripts/grant-access.sh $(USER)

set-github-token: ## Grava GITHUB_TOKEN no perfil do usuario: make set-github-token USER=admin
	./scripts/set-github-token.sh $(USER)

migrate: ## Roda migrations
	$(DC) exec service python manage.py migrate

superuser: ## Cria superusuario interativo
	$(DC) exec service python manage.py createsuperuser

shell-service: ## Shell do Django
	$(DC) exec service python manage.py shell

cli: ## Roda o CLI: make cli ARGS="calculate all -ep ..."
	$(COMPOSE_TOOLS) run --rm cli $(ARGS)

action-test: ## Sobe o container do Action e replaya os workflows com act
	$(COMPOSE_TOOLS) run --rm action bash -lc 'act -W .github/workflows || true'

submodules-update: ## Avanca os submodulos para o topo de develop
	./scripts/update-submodules.sh

semester: ## Aponta os submodulos para o fork do semestre (S no padrao AAAA.S): make semester S=2026.2
	./scripts/semester.sh use $(S)

semester-status: ## URL efetiva de cada submodulo + semestre configurado
	./scripts/semester.sh status

promote: ## Promove os submodulos do fork de semestre para o central
	./scripts/promote-to-central.sh

ai-up: ## Builda e sobe o servidor MCP (profile ai)
	$(DC) --profile ai up -d ai

ai-logs: ## Logs do servidor MCP
	$(DC) --profile ai logs -f ai

plugin: ## Roda um comando no container do Plugin: make plugin ARGS="npm install"
	$(DC) --profile tools run --rm plugin $(ARGS)

test-service: ## Suite do Service dentro do container
	$(DC) exec service pytest

test-front: ## Suite do Front dentro do container
	$(DC) exec front pnpm test
