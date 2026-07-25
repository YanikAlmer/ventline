# Shared helpers for the scratch-Postgres scripts. Source, don't execute.
# Provides: pg_setup, pg_start [port], pg_stop, PSQL[] array, pg_apply_all <db>

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)}"
if [ -z "$PGBIN" ] || [ ! -x "$PGBIN/initdb" ]; then
  if command -v initdb >/dev/null; then
    PGBIN="$(dirname "$(command -v initdb)")"
  else
    echo "error: PostgreSQL server binaries not found (set PGBIN=/path/to/pg/bin)" >&2
    exit 1
  fi
fi

SCRATCH="${VENTLINE_PG_DIR:-/tmp/ventline-pgscratch}"
DATADIR="$SCRATCH/data"
SOCKDIR="$SCRATCH/sock"
DB="ventline_scratch"

# Postgres refuses to run as root; drop to the postgres system user if needed.
RUN=()
if [ "$(id -u)" = "0" ]; then
  if id postgres >/dev/null 2>&1; then
    RUN=(runuser -u postgres --)
  else
    echo "error: running as root and no 'postgres' system user exists" >&2
    exit 1
  fi
fi
run() { "${RUN[@]}" "$@"; }

pg_setup() {
  mkdir -p "$DATADIR" "$SOCKDIR"
  if [ "$(id -u)" = "0" ]; then
    chown -R postgres:postgres "$SCRATCH"
  fi
  if [ ! -f "$DATADIR/PG_VERSION" ]; then
    echo "==> initdb ($DATADIR)"
    # Pin UTF8 explicitly. Supabase runs UTF8, and inheriting a C/POSIX locale
    # here silently produces a SQL_ASCII cluster where the text-search parser
    # treats "ü" as two non-letters — "Lüftung" tokenizes as "l" + "ftung" and
    # every German full-text assertion becomes meaningless.
    run "$PGBIN/initdb" -D "$DATADIR" -A trust -U postgres --no-instructions \
      --encoding=UTF8 --locale="${VENTLINE_PG_LOCALE:-C.UTF-8}" >/dev/null
  fi
}

# pg_start [tcp_port] — no port: unix socket only.
PG_PORT=""
pg_start() {
  local port="${1:-}"
  local opts="-c wal_level=logical -k $SOCKDIR"
  if [ -n "$port" ]; then
    opts="$opts -c listen_addresses=127.0.0.1 -c port=$port"
    PG_PORT="$port"
  else
    opts="$opts -c listen_addresses=''"
    PG_PORT=""
  fi
  run "$PGBIN/pg_ctl" -D "$DATADIR" -m fast stop >/dev/null 2>&1 || true
  echo "==> starting scratch Postgres${port:+ (127.0.0.1:$port)}"
  run "$PGBIN/pg_ctl" -D "$DATADIR" -w -l "$SCRATCH/pg.log" -o "$opts" start >/dev/null
}

pg_stop() {
  run "$PGBIN/pg_ctl" -D "$DATADIR" -m fast stop >/dev/null 2>&1 || true
}

psql_run() {
  run "$PGBIN/psql" -v ON_ERROR_STOP=1 -q -h "$SOCKDIR" ${PG_PORT:+-p "$PG_PORT"} -U postgres "$@"
}

# Recreate $DB and apply shim + every migration (not seed/tests).
pg_apply_all() {
  echo "==> recreating $DB"
  psql_run -d postgres -c "drop database if exists $DB;" -c "create database $DB;" >/dev/null
  echo "==> applying platform shim"
  psql_run -d "$DB" -f "$REPO/scripts/auth-shim.sql"
  local mig
  for mig in "$REPO"/supabase/migrations/*.sql; do
    echo "==> applying $(basename "$mig")"
    psql_run -d "$DB" -f "$mig"
  done
}
