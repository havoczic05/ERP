#!/usr/bin/env bash
# Build script used by Render (native Ruby environment).
# Runs on every deploy: install gems, precompile assets, run migrations.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate
