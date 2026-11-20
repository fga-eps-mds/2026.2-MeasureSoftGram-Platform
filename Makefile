SHELL := /bin/bash
DC := docker compose
DC_E2E := docker compose -p msgram-e2e -f docker-compose.yml -f docker-compose.e2e.yml --profile front

WEBLATE_URL ?= http://localhost:$${WEBLATE_PORT:-8090}
WEBLATE_TOKEN = $$($(DC) exec -T weblate weblate shell -c 'from rest_framework.authtoken.models import Token; from weblate.auth.models import User; print(Token.objects.get_or_create(user=User.objects.get(username="admin"))[0].key)' | tail -1)
WEBLATE_ENV = WEBLATE_URL=$(WEBLATE_URL) WEBLATE_API_TOKEN=$(WEBLATE_TOKEN)

.DEFAULT_GOAL := help
.PHONY: help select up down restart clean logs ps smoke \
        seed grant-access set-github-token migrate superuser shell-service \
        cli action-test plugin test-service test-front \
        e2e-up e2e-test e2e-down weblate-init weblate-pull

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

clean: ## Para a stack e APAGA volumes (dados do Postgres)
	$(DC) down -v

logs: ## Logs (make logs S=service para um servico)
	$(DC) logs -f $(S)

ps: ## Status dos containers
	$(DC) ps

smoke: ## Roda o smoke test
	./scripts/smoke-test.sh

seed: ## Repopula dados iniciais e de demonstracao
	$(DC) exec service python manage.py load_initial_data
	$(DC) exec service python manage.py seed_grafana

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

e2e-up: ## Sobe a stack do E2E de sistema (build do Front, seed fixo, fake-gitlab) e espera ficar saudavel
	$(DC_E2E) up -d --build --wait --wait-timeout 600

e2e-test: ## Roda a suite Playwright de e2e/ contra http://localhost (stack do e2e-up no ar)
	cd e2e && npm ci && npx playwright install chromium && npm test

e2e-down: ## Derruba a stack do E2E e apaga os volumes
	$(DC_E2E) down -v

weblate-init: ## Cria/atualiza no Weblate o projeto, os componentes e o glossario de weblate/ (idempotente)
	$(WEBLATE_ENV) python3 weblate/bootstrap.py init

weblate-pull: ## Puxa o develop dos repositorios para o Weblate
	$(WEBLATE_ENV) python3 weblate/bootstrap.py pull
