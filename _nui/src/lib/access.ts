import type { OrgPage, OrgSession } from './types';

export type Nav = { groups: OrgPage[][]; locked: OrgPage[] };

const managerPages: OrgPage[] = ['overview', 'employees', 'requests', 'society', 'vehicles', 'ranks', 'settings'];

export function hasRequestKinds(session: OrgSession): boolean {
  const { applications, leaves, reports } = session.features;
  return applications || leaves || reports;
}

function featureOn(session: OrgSession, page: OrgPage): boolean {
  const { features } = session;

  switch (page) {
    case 'requests':
      return hasRequestKinds(session);
    case 'society':
      return features.society;
    case 'vehicles':
      return features.vehicles;
    case 'announcements':
      return features.announcements;
    default:
      return true;
  }
}

function permitted(session: OrgSession, page: OrgPage): boolean {
  const { access } = session;

  switch (page) {
    case 'overview':
      return access.overview;
    case 'employees':
      return access.employees;
    case 'requests':
      return access.requests;
    case 'society':
      return access.society;
    case 'vehicles':
      return access.vehicles;
    case 'announcements':
      return true;
    case 'ranks':
      return access.ranks;
    case 'settings':
      return access.settings;
    case 'myJob':
      return !session.me.isBoss && !showsJobs(session);
    case 'myJobs':
      return showsJobs(session);
    default: {
      const exhaustive: never = page;
      return exhaustive;
    }
  }
}

export function showsJobs(session: OrgSession): boolean {
  return session.features.secondJobs && session.myJobs.length > 1;
}

export function isManager(session: OrgSession): boolean {
  return managerPages.some((page) => featureOn(session, page) && permitted(session, page));
}

export function canOpen(session: OrgSession, page: OrgPage): boolean {
  return featureOn(session, page) && permitted(session, page);
}

export function navFor(session: OrgSession): Nav {
  const keep = (pages: OrgPage[]) => pages.filter((page) => canOpen(session, page));

  if (isManager(session)) {
    return {
      groups: [
        keep(['overview', 'employees', 'requests', 'society', 'vehicles', 'announcements', 'myJob', 'myJobs']),
        keep(['ranks', 'settings']),
      ].filter((group) => group.length > 0),
      locked: [],
    };
  }

  return {
    groups: [keep(['myJob', 'myJobs', 'announcements'])],
    locked: (['employees', 'requests', 'society', 'vehicles', 'ranks'] satisfies OrgPage[]).filter((page) =>
      featureOn(session, page),
    ),
  };
}

export function firstPage(session: OrgSession): OrgPage {
  return navFor(session).groups[0]?.[0] ?? 'announcements';
}
