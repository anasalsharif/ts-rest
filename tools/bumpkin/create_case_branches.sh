#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE_BRANCH="${1:-main}"
FIXTURE_FILE="libs/ts-rest/core/src/lib/bumpkin-fixture.ts"
DOC_NOTE="docs/bumpkin/fixture-cases.md"
README_FILE="README.md"
ISSUE_TEMPLATE=".github/ISSUE_TEMPLATE/feature_request.md"
MANIFEST="tools/bumpkin/case_manifest.tsv"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree must be clean before generating case branches."
  exit 1
fi

if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "Base branch '$BASE_BRANCH' not found."
  exit 1
fi

replace_once() {
  local old="$1"
  local new="$2"
  python3 - "$FIXTURE_FILE" "$old" "$new" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = sys.argv[2]
new = sys.argv[3]
text = path.read_text()
if old not in text:
    raise SystemExit("pattern not found")
path.write_text(text.replace(old, new, 1))
PY
}

restore_base_files() {
  git checkout "$BASE_BRANCH" -- "$FIXTURE_FILE" "$DOC_NOTE" "$README_FILE" "$ISSUE_TEMPLATE"
}

apply_case() {
  local case_id="$1"

  case "$case_id" in
    01)
      replace_once "export type FixtureFetchUser = (id: string) => Promise<FixtureUser>;" \
        "export type FixtureFetchUser = (id: string, tenantId: string) => Promise<FixtureUser>;"
      ;;
    02)
      replace_once $'export function fixtureSlugFromEmail(email: string): string {\n  return collapseWhitespace(email).toLowerCase().replace(/[^a-z0-9]+/g, '-');\n}\n\n' ""
      ;;
    03)
      replace_once "  email: string;" "  primaryEmail: string;"
      ;;
    04)
      replace_once $'export function fixtureNormalizeTag(tag: string): string {\n  return collapseWhitespace(tag).toLowerCase();\n}' \
        $'export function fixtureNormalizeTag(tag: string): number {\n  return collapseWhitespace(tag).length;\n}'
      ;;
    05)
      replace_once "export function fixtureIsActive(user: FixtureUser): boolean {" \
        $'export function fixtureParseDomain(email: string): string {\n  return email.split("@")[1] ?? "";\n}\n\nexport function fixtureIsActive(user: FixtureUser): boolean {'
      ;;
    06)
      replace_once "export const FIXTURE_PAGE_SIZE = 20;" $'export const FIXTURE_PAGE_SIZE = 20;\nexport const FIXTURE_MAX_RETRIES = 3;'
      ;;
    07)
      replace_once "  active: boolean;" $'  active: boolean;\n  displayName?: string;'
      ;;
    08)
      replace_once "export const FIXTURE_PAGE_SIZE = 20;" $'export const FIXTURE_PAGE_SIZE = 20;\n\nexport type FixtureUserRole = "admin" | "member";'
      ;;
    09)
      replace_once $'export function fixtureNormalizeTag(tag: string): string {\n  return collapseWhitespace(tag).toLowerCase();\n}' \
        $'export function fixtureNormalizeTag(tag: string, opts?: { preserveCase?: boolean }): string {\n  const normalized = collapseWhitespace(tag);\n  return opts?.preserveCase ? normalized : normalized.toLowerCase();\n}'
      ;;
    10)
      replace_once "export function fixtureNormalizeTag(tag: string): string {" \
        $'export function fixtureToPublicUser(user: FixtureUser): Pick<FixtureUser, "id" | "active"> {\n  return { id: user.id, active: user.active };\n}\n\nexport function fixtureNormalizeTag(tag: string): string {'
      ;;
    11)
      replace_once "return collapseWhitespace(email).toLowerCase().replace(/[^a-z0-9]+/g, '-');" \
        "return collapseWhitespace(email).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-{2,}/g, '-');"
      ;;
    12)
      replace_once "return user.active;" "return Boolean(user.active);"
      ;;
    13)
      replace_once "export const FIXTURE_PAGE_SIZE = 20;" "export const FIXTURE_PAGE_SIZE = 25;"
      ;;
    14)
      replace_once "return value.trim().replace(/\\s+/g, ' ');" "return value.trim().replace(/[ _]+/g, ' ').replace(/\\s+/g, ' ');"
      ;;
    15)
      replace_once "return collapseWhitespace(tag).toLowerCase();" "return collapseWhitespace(tag).toLowerCase().replace(/[-.]+$/g, '');"
      ;;
    16)
      replace_once $'export function fixtureSlugFromEmail(email: string): string {\n  return collapseWhitespace(email).toLowerCase().replace(/[^a-z0-9]+/g, '-');\n}' \
        $'export function fixtureSlugFromEmail(email: string): string {\n  if (!email.trim()) {\n    return "user";\n  }\n  return collapseWhitespace(email).toLowerCase().replace(/[^a-z0-9]+/g, '-');\n}'
      ;;
    17)
      printf "\n- Case 17: docs-only note refreshed for NO_BUMP validation.\n" >> "$DOC_NOTE"
      ;;
    18)
      printf "\n<!-- bumpkin-fixture: docs-only wording update for no-bump case -->\n" >> "$README_FILE"
      ;;
    19)
      printf "\n<!-- bumpkin-fixture wording tweak for no-bump case -->\n" >> "$ISSUE_TEMPLATE"
      ;;
    20)
      mkdir -p docs/bumpkin
      cat > docs/bumpkin/no-bump-checklist.md <<'MD'
# No-Bump Checklist

- Confirm only docs/config files changed.
- Confirm no runtime API files changed.
- Confirm no exported signatures changed.
MD
      ;;
    *)
      echo "Unknown case: $case_id"
      exit 1
      ;;
  esac
}

while IFS=$'\t' read -r case_id expected branch_name title; do
  [[ "$case_id" == "case_id" ]] && continue

  git checkout "$BASE_BRANCH"
  git checkout -B "$branch_name"

  restore_base_files
  if [[ "$case_id" != "20" ]]; then
    git rm -f docs/bumpkin/no-bump-checklist.md >/dev/null 2>&1 || true
  fi

  apply_case "$case_id"

  git add -A
  git commit -m "$title"
  printf "Created %s (expected %s)\n" "$branch_name" "$expected"
done < "$MANIFEST"

git checkout "$BASE_BRANCH"
printf "\nAll fixture branches created from %s.\n" "$BASE_BRANCH"
