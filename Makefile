SHELL := /bin/bash
DC := docker compose

.DEFAULT_GOAL := help
.PHONY: help select up down restart clean logs ps smoke \
        seed grant-access set-github-token migrate superuser shell-service \
        cli action-test plugin test-service test-front

help: ## Lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	 awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

select: ## Escolhe quais servicos sobem (menu interativo, grava no .env)
	./scripts/select.sh

up: ## Sobe os servicos marcados em COMPOSE_PROFILES no .env
	$(DC) up -d --build

down: ## Para a stack (mantem volumes)
	$(DC) down

restart: down up ## down + up

clean: ## Para a stack e APAGA volumes (dados do Postgres/Grafana)
	$(DC) down -v

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
	$(DC) run --rm cli $(ARGS)

action-test: ## Sobe o container do Action e replaya os workflows com act
	$(DC) run --rm action bash -lc 'act -W .github/workflows || true'

plugin: ## Roda um comando no container do Plugin: make plugin ARGS="npm install"
	$(DC) run --rm plugin $(ARGS)

test-service: ## Suite do Service dentro do container
	$(DC) exec service pytest

test-front: ## Suite do Front dentro do container
	$(DC) exec front pnpm test
