#!/usr/bin/env bash
# Build script used by Render (native Ruby environment).
# Runs on every deploy: install gems, precompile assets, run migrations, seed
# core records. In production `db:seed` is idempotent and only ensures login
# users, warehouses and company settings — it stops before the demo dataset.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate
bundle exec rails db:seed
