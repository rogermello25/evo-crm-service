# Variables
APP_NAME := evolution
RAILS_ENV ?= development

.PHONY: setup dev run install db-setup db-migrate db-seed db-reset db_create db_migrate db_seed db_reset db console server burn docker run force_run force_run_tunnel debug debug_worker help

# =============================================================================
# PADRÃO PADRONIZADO - COMANDOS PRINCIPAIS
# =============================================================================

# Setup completo do projeto (install + db-setup)
setup: install db-setup
	@echo "✅ Setup completo concluído!"

# Instalar dependências
install:
	@echo "📦 Instalando dependências..."
	gem install bundler || true
	bundle install
	pnpm install
	@echo "✅ Dependências instaladas!"

# Rodar em modo desenvolvimento
dev:
	@echo "🔧 Iniciando EvoAI CRM em modo desenvolvimento..."
	@if [ -f ./.overmind.sock ]; then \
		echo "Overmind já está rodando. Use 'make force_run' para iniciar uma nova instância."; \
	else \
		overmind start -f Procfile.dev; \
	fi

# Rodar em modo produção
run:
	@echo "🚀 Iniciando EvoAI CRM em modo produção..."
	RAILS_ENV=production bundle exec rails server -b 0.0.0.0 -p 3000

# Setup do banco de dados (create + migrate)
db-setup:
	@echo "🗄️  Configurando banco de dados..."
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:create || true
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate
	@echo "✅ Banco de dados configurado!"

# Rodar migrações pendentes
db-migrate:
	@echo "🚀 Rodando migrações pendentes..."
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate
	@echo "✅ Migrações aplicadas!"

# Rodar seeds
db-seed:
	@echo "🌱 Rodando seeds..."
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:seed
	@echo "✅ Seeds executados!"

# Resetar banco completo
db-reset:
	@echo "🔄 Resetando banco de dados..."
	@echo "⚠️  ATENÇÃO: Isso irá apagar todos os dados!"
	@read -p "Tem certeza? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:reset
	@echo "✅ Banco de dados resetado!"

# =============================================================================
# COMANDOS COMPATIBILIDADE (snake_case)
# =============================================================================

db_create: db-setup
	@echo "⚠️  Use 'make db-setup' (padrão padronizado)"

db_migrate: db-migrate
	@echo "⚠️  Use 'make db-migrate' (padrão padronizado)"

db_seed: db-seed
	@echo "⚠️  Use 'make db-seed' (padrão padronizado)"

db_reset: db-reset
	@echo "⚠️  Use 'make db-reset' (padrão padronizado)"

# =============================================================================
# COMANDOS ADICIONAIS
# =============================================================================

db:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:evolution_prepare

console:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails console

server:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

burn:
	bundle && pnpm install

force_run:
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.dev

force_run_tunnel:
	lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.tunnel

debug:
	overmind connect backend

debug_worker:
	overmind connect worker

docker:
	docker build -t $(APP_NAME) -f ./docker/Dockerfile .

# =============================================================================
# HELP
# =============================================================================

help: ## Mostrar ajuda com todos os comandos
	@echo "EvoAI CRM - Makefile Commands"
	@echo ""
	@echo "🚀 Quick Start (PADRÃO PADRONIZADO):"
	@echo "  make setup          - Setup completo (install + db-setup)"
	@echo "  make dev            - Rodar em modo desenvolvimento"
	@echo "  make run            - Rodar em modo produção"
	@echo ""
	@echo "📦 Setup & Installation:"
	@echo "  make install        - Instalar dependências"
	@echo "  make setup          - Setup completo (install + db-setup)"
	@echo ""
	@echo "🗄️ Database Management (PADRÃO PADRONIZADO):"
	@echo "  make db-setup       - Setup inicial do banco (create + migrate)"
	@echo "  make db-migrate     - Rodar migrações pendentes"
	@echo "  make db-seed        - Rodar seeds"
	@echo "  make db-reset       - Resetar banco completo"
	@echo ""
	@echo "🔄 Comandos de Compatibilidade (snake_case):"
	@echo "  make db_create      - Alias para db-setup"
	@echo "  make db_migrate     - Alias para db-migrate"
	@echo "  make db_seed        - Alias para db-seed"
	@echo "  make db_reset       - Alias para db-reset"
	@echo ""
	@echo "🛠️ Development:"
	@echo "  make console        - Abrir console Rails"
	@echo "  make server         - Iniciar servidor Rails"
	@echo "  make force_run      - Forçar início com Overmind"
	@echo "  make debug          - Conectar ao backend via Overmind"
	@echo "  make debug_worker   - Conectar ao worker via Overmind"
	@echo ""
