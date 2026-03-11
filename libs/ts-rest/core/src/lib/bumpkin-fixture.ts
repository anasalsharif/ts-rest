export interface FixtureUser {
  id: string;
  primaryEmail: string;
  active: boolean;
}

export type FixtureFetchUser = (id: string, tenantId: string) => Promise<FixtureUser>;

export const FIXTURE_API_VERSION = 'v1';
export const FIXTURE_PAGE_SIZE = 20;

export function fixtureDomainFromEmail(email: string): string {
  return email.split('@')[1] ?? '';
}

export function fixtureIsActive(user: FixtureUser): boolean {
  return user.active;
}

export function fixtureNormalizeTag(tag: string): number {
  return collapseWhitespace(tag).length;
}

function collapseWhitespace(value: string): string {
  return value.trim().replace(/\s+/g, ' ');
}
