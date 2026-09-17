#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-migrations.py
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
# All database commands explicitly target local; this clears local test data.
supabase db start
supabase db reset --local --no-seed
supabase test db --local
# Also exercise upgrading existing data, not only building an empty database.
supabase db reset --local --no-seed --version 20260912000000
supabase db query --local --file scripts/migration-fixtures/upgrade.sql >/dev/null
supabase migration up --local
supabase test db --local
supabase test db --local scripts/migration-fixtures/preserve_data.sql
