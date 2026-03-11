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

restore_base_files() {
  git checkout "$BASE_BRANCH" -- "$FIXTURE_FILE" "$DOC_NOTE" "$README_FILE" "$ISSUE_TEMPLATE"
}

apply_case() {
  local case_id="$1"

  case "$case_id" in
    01)
      perl -0pi -e "s/export type FixtureFetchUser = \(id: string\) => Promise<FixtureUser>;/export type FixtureFetchUser = (id: string, tenantId: string) => Promise<FixtureUser>;/" "$FIXTURE_FILE"
      ;;
    02)
      perl -0pi -e "s/export function fixtureSlugFromEmail\(email: string\): string \{\n  return collapseWhitespace\(email\)\.toLowerCase\(\)\.replace\(\/\[\^a-z0-9\]\+\/g, '-'\);\n\}\n\n//s" "$FIXTURE_FILE"
      ;;
    03)
      perl -0pi -e "s/  email: string;/  primaryEmail: string;/" "$FIXTURE_FILE"
      ;;
    04)
      perl -0pi -e "s/export function fixtureNormalizeTag\(tag: string\): string \{\n  return collapseWhitespace\(tag\)\.toLowerCase\(\);\n\}/export function fixtureNormalizeTag(tag: string): number {\n  return collapseWhitespace(tag).length;\n}/" "$FIXTURE_FILE"
      ;;
    05)
      perl -0pi -e "s/export function fixtureIsActive\(user: FixtureUser\): boolean \{/export function fixtureParseDomain(email: string): string {\n  return email.split('@')[1] ?? '';\n}\n\nexport function fixtureIsActive(user: FixtureUser): boolean {/" "$FIXTURE_FILE"
      ;;
    06)
      perl -0pi -e "s/export const FIXTURE_PAGE_SIZE = 20;/export const FIXTURE_PAGE_SIZE = 20;\nexport const FIXTURE_MAX_RETRIES = 3;/" "$FIXTURE_FILE"
      ;;
    07)
      perl -0pi -e "s/  active: boolean;/  active: boolean;\n  displayName?: string;/" "$FIXTURE_FILE"
      ;;
    08)
      perl -0pi -e "s/export const FIXTURE_PAGE_SIZE = 20;/export const FIXTURE_PAGE_SIZE = 20;\n\nexport type FixtureUserRole = 'admin' | 'member';/" "$FIXTURE_FILE"
      ;;
    09)
      perl -0pi -e "s/export function fixtureNormalizeTag\(tag: string\): string \{\n  return collapseWhitespace\(tag\)\.toLowerCase\(\);\n\}/export function fixtureNormalizeTag(tag: string, opts?: { preserveCase?: boolean }): string {\n  const normalized = collapseWhitespace(tag);\n  return opts?.preserveCase ? normalized : normalized.toLowerCase();\n}/" "$FIXTURE_FILE"
      ;;
    10)
      perl -0pi -e "s/export function fixtureNormalizeTag\(tag: string\): string \{/export function fixtureToPublicUser(user: FixtureUser): Pick<FixtureUser, 'id' | 'active'> {\n  return { id: user.id, active: user.active };\n}\n\nexport function fixtureNormalizeTag(tag: string): string {/" "$FIXTURE_FILE"
      ;;
    11)
      perl -0pi -e "s/return collapseWhitespace\(email\)\.toLowerCase\(\)\.replace\(\/\[\^a-z0-9\]\+\/g, '-'\);/return collapseWhitespace(email).toLowerCase().replace(\/[^a-z0-9]+\/g, '-').replace(\/-{2,}\/g, '-');/" "$FIXTURE_FILE"
      ;;
    12)
      perl -0pi -e "s/return user\.active;/return Boolean(user.active);/" "$FIXTURE_FILE"
      ;;
    13)
      perl -0pi -e "s/export const FIXTURE_PAGE_SIZE = 20;/export const FIXTURE_PAGE_SIZE = 25;/" "$FIXTURE_FILE"
      ;;
    14)
      perl -0pi -e "s/return value\.trim\(\)\.replace\(\\s\+\/g, ' '\);/return value.trim().replace(\/[ _]+\/g, ' ').replace(\\/\\s+\\/g, ' ');/" "$FIXTURE_FILE"
      ;;
    15)
      perl -0pi -e "s/return collapseWhitespace\(tag\)\.toLowerCase\(\);/return collapseWhitespace(tag).toLowerCase().replace(/[-.]+4/, '');/" "$FIXTURE_FILE"
      ;;
    16)
      perl -0pi -e "s/export function fixtureSlugFromEmail\(email: string\): string \{\n  return collapseWhitespace\(email\)\.toLowerCase\(\)\.replace\(\/\[\^a-z0-9\]\+\/g, '-'\);\n\}/export function fixtureSlugFromEmail(email: string): string {\n  if (!email.trim()) {\n    return 'user';\n  }\n  return collapseWhitespace(email).toLowerCase().replace(\/[^a-z0-9]+\/g, '-');\n}/" "$FIXTURE_FILE"
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
