#!/usr/bin/env bash
# Regenerate client model types from the actual schema:
#   web/src/lib/database.types.ts                        (TypeScript)
#   ios/Ventline/Core/Models/GeneratedModels.swift       (Swift)
#
# Applies all migrations to the scratch Postgres first, so the output always
# matches the migrations in this repo.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/pglib.sh"

PORT="${VENTLINE_PG_PORT:-55432}"
DB_URL="postgresql://postgres@127.0.0.1:$PORT/$DB"

pg_setup
pg_start "$PORT"
trap pg_stop EXIT

pg_apply_all

echo "==> generating TypeScript + Swift types"
node "$REPO/scripts/gen-types.mjs" "$DB_URL"

echo
echo "OK: types regenerated."
