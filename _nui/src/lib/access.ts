import type { JobPage, JobSession } from './types';

export type Nav = { groups: JobPage[][]; locked: JobPage[] };

const managerPages: JobPage[] = ['overview', 'employees', 'requests', 'society', 'vehicles', 'ranks', 'settings'];

export function hasRequestKinds(session: JobSession): boolean {
  const { applications, leaves, reports } = session.features;
  return applications || leaves || reports;
}

function featureOn(session: JobSession, page: JobPage): boolean {
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

function permitted(session: JobSession, page: JobPage): boolean {
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

export function showsJobs(session: JobSession): boolean {
  return session.features.secondJobs && session.myJobs.length > 1;
}

export function isManager(session: JobSession): boolean {
  return managerPages.some((page) => featureOn(session, page) && permitted(session, page));
}

export function canOpen(session: JobSession, page: JobPage): boolean {
  return featureOn(session, page) && permitted(session, page);
}

export function navFor(session: JobSession): Nav {
  const keep = (pages: JobPage[]) => pages.filter((page) => canOpen(session, page));

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
    locked: (['employees', 'requests', 'society', 'vehicles', 'ranks'] satisfies JobPage[]).filter((page) =>
      featureOn(session, page),
    ),
  };
}

export function firstPage(session: JobSession): JobPage {
  return navFor(session).groups[0]?.[0] ?? 'announcements';
}
