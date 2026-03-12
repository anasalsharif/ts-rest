export interface FixtureUser {
  id: string;
  primaryEmail: string;
  active: boolean;
  displayName: string | null;
}

export type FixtureFetchUser = (id: string, tenantId: string) => Promise<FixtureUser>;

export const FIXTURE_API_VERSION = 'v1';
export const FIXTURE_PAGE_SIZE = 25;
export const FIXTURE_SEARCH_LIMIT = 10;
export const FIXTURE_DEFAULT_ROLE: FixtureUserRole = 'member';
export const FIXTURE_STATUS_LABEL = 'stable';
export const FIXTURE_STATUS_CHANNEL = 'public';
export const FIXTURE_EXPERIMENTAL_BATCH_SIZE = 50;
export const FIXTURE_RETRY_WINDOW_MS = 1500;

export type FixtureUserRole = 'admin' | 'member';

export function fixtureDomainFromEmail(email: string): string {
  const normalized = email.trim().toLowerCase();
  if (!normalized) {
    return '';
  }
  return normalized.split('@')[1] ?? '';
}

export function fixtureIsActive(user: FixtureUser): boolean {
  return Boolean(user.active);
}

export function fixtureToCompactUser(user: FixtureUser): Pick<FixtureUser, 'id' | 'active'> {
  return { id: user.id, active: user.active };
}

export function fixtureNormalizeTag(tag: string, opts?: { trimOnly?: boolean }): number {
  const normalized = collapseWhitespace(tag, true);
  const lowered = normalized.toLowerCase().replace(/[-.]+$/g, '');
  return opts?.trimOnly ? normalized.length : lowered.length;
}

function collapseWhitespace(value: string, collapseTabs: boolean): string {
  const collapsePattern = collapseTabs ? /[_\t ]+/g : /[ _]+/g;
  return value.trim().replace(collapsePattern, ' ').replace(/\s+/g, ' ').replace(/ {2,}/g, ' ');
}
