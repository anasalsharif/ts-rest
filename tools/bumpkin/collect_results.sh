#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OUT_DIR="artifacts/live-pr-validation"
mkdir -p "$OUT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required for result collection."
  exit 1
fi

repo="${1:-}"
if [[ -z "$repo" ]]; then
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

gh pr list --repo "$repo" --state merged --limit 200 \
  --json number,title,url,labels,mergedAt \
  --jq '.[] | [.number, .title, .url, .mergedAt] | @tsv' \
  > "$OUT_DIR/results.tsv"

echo -e "pr\ttitle\turl\tmerged_at" | cat - "$OUT_DIR/results.tsv" > "$OUT_DIR/results.with-header.tsv"
mv "$OUT_DIR/results.with-header.tsv" "$OUT_DIR/results.tsv"

echo "Wrote $OUT_DIR/results.tsv"
