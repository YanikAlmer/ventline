#!/usr/bin/env bash
# Validate the Supabase migrations against a real local Postgres 16:
# scratch cluster -> auth/storage shim -> every migration -> seed -> RLS tests.
#
# Requires the postgresql-16 server package (initdb/pg_ctl/psql). No Docker.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/pglib.sh"

pg_setup
pg_start
trap pg_stop EXIT

pg_apply_all

echo "==> applying seed.sql"
psql_run -d "$DB" -f "$REPO/supabase/seed.sql"

echo "==> running RLS tests"
psql_run -d "$DB" -f "$REPO/scripts/rls-tests.sql"

echo
echo "OK: all migrations, seed, and RLS tests passed."
