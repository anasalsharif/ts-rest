#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE_BRANCH="${1:-main}"
MANIFEST="tools/bumpkin/case_manifest.tsv"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required."
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "origin remote is not configured."
  exit 1
fi

while IFS=$'\t' read -r case_id expected branch_name title; do
  [[ "$case_id" == "case_id" ]] && continue

  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    echo "Skipping missing branch: $branch_name"
    continue
  fi

  git push -u origin "$branch_name"

  existing_count="$(gh pr list --head "$branch_name" --state open --json number --jq 'length')"
  if [[ "$existing_count" != "0" ]]; then
    echo "PR already open for $branch_name"
    continue
  fi

  gh pr create \
    --base "$BASE_BRANCH" \
    --head "$branch_name" \
    --title "$title" \
    --body "Fixture case ${case_id}. Expected bump: ${expected}."

done < "$MANIFEST"

echo "Finished opening fixture PRs."
