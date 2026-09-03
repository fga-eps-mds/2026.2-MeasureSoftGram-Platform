SHELL := /bin/bash
DC := docker compose --env-file .env
COMPOSE_TOOLS := $(DC) --profile tools

.DEFAULT_GOAL := help
.PHONY: help setup up up-min down restart clean build rebuild logs ps smoke \
        seed migrate superuser shell-service cli action-test \
        submodules-update use-fork test-service test-front

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

use-fork: ## Aponta os submodulos para forks: make use-fork GH_USER=<user>
	./scripts/use-fork.sh $(GH_USER)

test-service: ## Suite do Service dentro do container
	$(DC) exec service pytest

test-front: ## Suite do Front dentro do container
	$(DC) exec front pnpm test
