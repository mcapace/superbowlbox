#!/usr/bin/env bash
# Create SquareUp Supabase tables (shared_pools + logins) via CLI.
# Run from repo root. Requires: supabase CLI, supabase login.
#
# Usage:
#   SUPABASE_PROJECT_REF=your-ref ./scripts/supabase-setup.sh
#   ./scripts/supabase-setup.sh your-project-ref
#
# Optional (to avoid password prompt):
#   SUPABASE_DB_PASSWORD=your-db-password ./scripts/supabase-setup.sh your-ref

set -e

PROJECT_REF="${SUPABASE_PROJECT_REF:-$1}"
if [[ -z "$PROJECT_REF" ]]; then
  echo "Usage: SUPABASE_PROJECT_REF=your-ref $0"
  echo "   or: $0 your-project-ref"
  echo ""
  echo "Project ref is in the dashboard URL: https://supabase.com/dashboard/project/<project-ref>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v supabase &>/dev/null; then
  echo "Supabase CLI not found. Install: brew install supabase/tap/supabase"
  exit 1
fi

LINK_ARGS=(--project-ref "$PROJECT_REF")
PUSH_ARGS=()
if [[ -n "$SUPABASE_DB_PASSWORD" ]]; then
  LINK_ARGS+=(--password "$SUPABASE_DB_PASSWORD")
  PUSH_ARGS+=(--password "$SUPABASE_DB_PASSWORD")
fi

echo "Linking project $PROJECT_REF..."
supabase link "${LINK_ARGS[@]}"

echo "Pushing migrations (creating shared_pools + logins)..."
supabase db push "${PUSH_ARGS[@]}"

echo "Done. Tables shared_pools and logins are ready."
echo "Ensure SuperBowlBox/Resources/Secrets.plist has LoginDatabaseURL and LoginDatabaseApiKey set."
