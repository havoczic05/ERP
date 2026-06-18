# ERP

Single-company web ERP (Rails 8) for an electronics-components importer:
inventory, sales/quotations, and installment-based accounts receivable. All
financial values are in **USD**.

📐 **Architecture:** see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the
stack, domain model, and the conventions all modules follow.

## Tech stack

- **Ruby** 3.4.9 / **Rails** 8.1
- **PostgreSQL** (app DB + Solid Queue/Cache/Cable databases)
- **Propshaft** + **importmap-rails** + **Hotwire** (Turbo/Stimulus) — no JS bundler
- **Puma** (with **Thruster** in production), **Pundit**, **Pagy**, **Prawn** (PDFs)

## Prerequisites

- Ruby **3.4.9** (matches `.ruby-version`)
- PostgreSQL **9.5+**, running locally
- A C toolchain + `libvips` (for Active Storage image processing)

## Setup

```bash
git clone https://github.com/havoczic05/ERP.git
cd ERP

bin/setup            # installs gems, prepares the DB, and boots the app
```

`bin/setup` runs `bundle install`, `bin/rails db:prepare` (create + migrate +
seed) and starts the server. To do it manually instead:

```bash
bundle install
bin/rails db:prepare      # create, migrate, seed
bin/dev                   # start the server on http://localhost:3000
```

### Seed data

`db/seeds.rb` is idempotent and creates:

- A default warehouse — **"Almacén Principal"**.
- A default admin user — **`admin@erp.local`**, password from
  `SEED_ADMIN_PASSWORD` (defaults to `changeme123`).

> Set `SEED_ADMIN_PASSWORD` before seeding in any shared environment. Roles are
> `administrador` and `vendedor`.

## Running

```bash
bin/dev                   # → http://localhost:3000  (equivalent to bin/rails server)
```

There is no JS build step — importmap serves ES modules directly.

## Testing & quality

The suite is **RSpec** (strict TDD; model, service, request and system specs;
system specs run on `rack_test`):

```bash
bundle exec rspec                  # full suite
bundle exec rubocop                # lint (rubocop-rails-omakase)
bin/brakeman                       # security static analysis
bin/bundler-audit                  # gem CVE audit
bin/ci                             # run the whole gate as CI does
```

> Note: a few JS-driven system behaviors are not covered automatically because
> the dev/CI environment has no headless Chrome (see "W-3" notes in the specs and
> `docs/ARCHITECTURE.md`).

## Environment variables

| Variable | Used for | Default |
| --- | --- | --- |
| `SEED_ADMIN_PASSWORD` | Initial admin password (seeds) | `changeme123` |
| `ERP_DATABASE_PASSWORD` | Production DB password | — |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` (production) | from `config/master.key` |
| `RAILS_MAX_THREADS` | DB pool / Puma threads | `5` |

## Deployment

The app ships a production-grade **`Dockerfile`** (Rails 8 default: Puma behind
Thruster, listening on port 80). Build and run the image directly:

```bash
docker build -t erp .
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=<config/master.key> \
  -e ERP_DATABASE_PASSWORD=<db-password> \
  --name erp erp
```

Run migrations against the production databases (app + Solid Queue/Cache) on
deploy:

```bash
bin/rails db:prepare
```

> **Kamal** is bundled (`gem "kamal"`) as the intended deploy tool, but is **not
> configured yet** — there is no `config/deploy.yml`. Run `kamal init` and fill in
> your servers/registry before using `kamal deploy`.

## Workflow

GitHub Flow: branch off `main`, open a PR, and merge once the CI gate (lint,
Brakeman, JS audit, RSpec) is green. `main` is protected and squash-only;
commits follow Conventional Commits.
