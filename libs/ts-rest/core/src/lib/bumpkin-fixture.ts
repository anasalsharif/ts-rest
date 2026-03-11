export interface FixtureUser {
  id: string;
  email: string;
  active: boolean;
}

export type FixtureFetchUser = (id: string) => Promise<FixtureUser>;

export const FIXTURE_API_VERSION = 'v1';
export const FIXTURE_PAGE_SIZE = 20;

export function fixtureIsActive(user: FixtureUser): boolean {
  return user.active;
}

export function fixtureNormalizeTag(tag: string): string {
  return collapseWhitespace(tag).toLowerCase();
}

function collapseWhitespace(value: string): string {
  return value.trim().replace(/\s+/g, ' ');
}
