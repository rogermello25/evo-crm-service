# Evolution CRM - Rails API

> Open-source customer support platform backend - Multi-tenant Rails API with real-time messaging

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Ruby Version](https://img.shields.io/badge/ruby-3.4.4-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-7.1-red.svg)](https://rubyonrails.org/)

Evolution CRM is a modern, open-source customer support platform backend built with Ruby on Rails. It provides a robust API for managing conversations, contacts, messages, and integrations across multiple communication channels.

## 🚀 Tech Stack

- **Backend**: Ruby on Rails 7.1 (API Mode)
- **Ruby**: 3.4.4
- **Database**: PostgreSQL (para Conversations, Contacts, Users, etc.)
- **Cache/Jobs**: Redis + Sidekiq
- **Real-time**: ActionCable (WebSocket)
- **Authentication**: Devise + JWT
- **File Storage**: AWS S3, Google Cloud Storage, Azure Blob

## 📦 Setup

### Prerequisites

```bash
# Required
- Ruby 3.4.4
- PostgreSQL
- Redis
- pnpm (for convenience scripts)
```

### Installation

```bash
# Install dependencies
bundle install
pnpm install  # Optional - for convenience scripts

# Setup database
bundle exec rails db:setup

# Run migrations
bundle exec rails db:migrate

```

## 🏃 Running

### Using pnpm (Recommended)

```bash
# Start everything (Rails + Sidekiq)
pnpm dev

# Or individual commands
pnpm start    # Rails server only
pnpm sidekiq  # Sidekiq worker only
```

### Using Overmind/Foreman

```bash
# All processes
overmind start -f Procfile.dev
# or
foreman start -f Procfile.dev
```

### Manual

```bash
# Rails server
bundle exec rails server -p 3000

# Sidekiq (separate terminal)
bundle exec sidekiq -C config/sidekiq.yml
```

## 🧪 Testing

```bash
# All tests
pnpm test
# or
bundle exec rspec

# Single file
bundle exec rspec spec/models/contact_spec.rb

# Single test
bundle exec rspec spec/models/contact_spec.rb:42
```

## 🔍 Linting

```bash
# Check
pnpm lint
# or
bundle exec rubocop

# Auto-fix
pnpm lint:fix
# or
bundle exec rubocop -a
```

## 📚 Available Scripts

All scripts are available through `pnpm`:

| Script            | Description               |
| ----------------- | ------------------------- |
| `pnpm dev`        | Start Rails + Sidekiq     |
| `pnpm start`      | Start Rails server        |
| `pnpm test`       | Run RSpec tests           |
| `pnpm lint`       | Run RuboCop               |
| `pnpm lint:fix`   | Run RuboCop with auto-fix |
| `pnpm db:setup`   | Setup database            |
| `pnpm db:migrate` | Run migrations            |
| `pnpm db:seed`    | Seed database             |
| `pnpm console`    | Rails console             |
| `pnpm sidekiq`    | Start Sidekiq             |

## 🏗️ Architecture

### API-Only Mode

This application runs in **Rails API mode** - no frontend views. The frontend is developed separately.

### Service Objects

Business logic is organized in Service Objects:

```
app/services/
├── base/
│   └── send_on_channel_service.rb
├── whatsapp/
│   └── message_processor_service.rb
└── crm/
    └── contact_sync_service.rb
```

### Event-Driven (Wisper)

Domain events are published for cross-cutting concerns:

- `contact.created`
- `conversation.resolved`
- `message.sent`

### Background Jobs (Sidekiq)

Heavy operations run asynchronously:

- External API calls
- Webhook processing
- Bulk operations

## 🔌 API

### Base URL

```
http://localhost:3000/api/v1
```

### Authentication

JWT tokens via `X-Auth-Token` header:

```bash
curl -H "X-Auth-Token: YOUR_TOKEN" \
     http://localhost:3000/api/v1/accounts/1/conversations
```

### Documentation

- **Swagger**: `http://localhost:3000/swagger`
- **API Docs**: `/swagger/index.html`

## 🔐 Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database
DATABASE_URL=postgresql://localhost/evolution_crm_development

# Redis
REDIS_URL=redis://localhost:6379/0

# ScyllaDB (optional - for high-performance message storage)
SCYLLA_ENABLED=true
SCYLLA_HOSTS=localhost
SCYLLA_PORT=9042
SCYLLA_KEYSPACE=evo_crm

# Frontend URL (for CORS)
FRONTEND_URL=http://localhost:8080

# Storage (S3, GCS, Azure)
ACTIVE_STORAGE_SERVICE=local

# See .env.example for all options
```

## 🐳 Docker

```bash
# Build
docker-compose build

# Run
docker-compose up

# Or specific services
docker-compose up backend worker
```

## 📖 Development Guidelines

For detailed development guidelines:

- Code style (RuboCop)
- Testing practices
- Service Object patterns
- Multi-tenant architecture
- Event-driven patterns

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

**Quick start:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

**Guidelines:**

- Follow RuboCop style guide
- Write tests for new features
- Use Service Objects for business logic
- Ensure multi-tenant scoping
- Document API changes in Swagger
- Follow [Conventional Commits](https://www.conventionalcommits.org/)

## 🐛 Reporting Issues

Found a bug? Have a feature request? Please [open an issue](https://github.com/EvolutionAPI/evolution/issues) on GitHub.

## 🔒 Security

Please see our [Security Policy](./SECURITY.md) for information on reporting security vulnerabilities.

## 📚 Documentation

- [API Documentation](./swagger/index.html) - Swagger/OpenAPI docs
- [Contributing Guide](./CONTRIBUTING.md) - How to contribute
- [Docker Guide](./docker/README.md) - Docker setup and optimization

## 🌟 Features

- ✅ **Multi-tenant** - Complete data isolation per account
- ✅ **Real-time** - WebSocket support via ActionCable
- ✅ **Multi-channel** - WhatsApp, Email, Web Widget, and more
- ✅ **RESTful API** - Comprehensive API with Swagger documentation
- ✅ **High-Performance Messages** - Optional ScyllaDB for ultra-fast message storage (<1ms latency)
- ✅ **Background Jobs** - Async processing with Sidekiq
- ✅ **Event-driven** - Domain events for extensibility
- ✅ **File Storage** - Support for S3, GCS, Azure Blob
- ✅ **Message Templates** - Rich email templates with drag-and-drop editor

## 🏢 Production Use

Evolution CRM is used in production by Evolution AI. For production deployments, see:

- [Docker Deployment](./docker/README.md)
- [Environment Variables](./.env.example)

## 📝 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

Evolution CRM is built on top of modern Ruby on Rails best practices and inspired by the open-source community.

---

**Evolution CRM** - Modern customer support platform backend

Made with ❤️ by [Evolution AI](https://evoai.app)
