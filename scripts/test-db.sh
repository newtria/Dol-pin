#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for suite in supabase/tests/*.sql; do
  docker exec -i supabase_db_dol-pin psql -U postgres -d postgres \
    -v ON_ERROR_STOP=1 < "$suite"
done
