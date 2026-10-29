#!/usr/bin/env bash
# Applies every migration to a throwaway Postgres and runs lock_direct_writes.sql.
# Needs docker; touches nothing but the disposable container.
set -euo pipefail
cd "$(dirname "$0")"
NAME=raghif-sqltest
IMAGE=${PG_IMAGE:-pgvector/pgvector:pg18}
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=x "$IMAGE" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1' EXIT
psql() { docker exec -i "$NAME" psql -U postgres -v ON_ERROR_STOP=1 -q "$@"; }
until docker exec "$NAME" pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
sleep 2
psql < stubs.sql
for f in ../migrations/*.sql; do
  echo "migration $(basename "$f")"
  # pg_net is a platform extension; the stub schema stands in for it.
  grep -v "create extension if not exists pg_net" "$f" | psql
done
psql < lock_direct_writes.sql
psql < notify_purchase.sql
psql < notification_inbox.sql
psql < update_my_profile.sql
psql < postpone_purchase.sql
echo "SQL tests passed"
