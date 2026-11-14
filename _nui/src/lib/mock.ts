import type { MockHandlers } from './nui';
import { toDay } from './format';
import type {
  Access,
  AdminMember,
  AdminSession,
  ApplySession,
  CharterSession,
  Employee,
  GangRank,
  GangSession,
  Iso,
  MapColour,
  OrgSession,
  Rank,
  RequestItem,
  Result,
  Session,
  Zone,
} from './types';

const MINUTE = 60000;
const DAY = 86400000;

const now = Date.now();

function at(daysAgo: number, hour?: number, minute = 0): Iso {
  const date = new Date(now - daysAgo * DAY);
  if (hour !== undefined) date.setHours(hour, minute, 0, 0);
  return date.toISOString();
}

function minutesAgo(minutes: number): Iso {
  return new Date(now - minutes * MINUTE).toISOString();
}

function inMinutes(minutes: number): Iso {
  return new Date(now + minutes * MINUTE).toISOString();
}

function day(offset: number): string {
  return toDay(new Date(now + offset * DAY));
}

function ok<S>(session: S): Result<S> {
  return { ok: true, session: structuredClone(session) };
}

function fail<S>(error: string): Result<S> {
  return { ok: false, error };
}

const ranks: Rank[] = [
  { grade: 5, name: 'Owner', pay: 900, isBoss: true, people: 1, permissions: [] },
  { grade: 4, name: 'Shop manager', pay: 650, isBoss: false, people: 2, permissions: ['open_menu', 'view_dashboard', 'give_bonus'] },
  { grade: 3, name: 'Lead mechanic', pay: 500, isBoss: false, people: 2, permissions: ['open_menu', 'view_dashboard'] },
  { grade: 2, name: 'Mechanic', pay: 400, isBoss: false, people: 8, permissions: [] },
  { grade: 1, name: 'Tow driver', pay: 300, isBoss: false, people: 2, permissions: [] },
  { grade: 0, name: 'Apprentice', pay: 250, isBoss: false, people: 3, permissions: [] },
];

const apprentice: Rank = { grade: 0, name: 'Apprentice', pay: 250, isBoss: false, people: 0, permissions: [] };

function rankOf(grade: number): Rank {
  return ranks.find((rank) => rank.grade === grade) ?? apprentice;
}

type Seed = [citizenid: string, name: string, grade: number, joined: number, week: number, shift: number | null, extra?: Partial<Employee>];

const seeds: Seed[] = [
  ['LKR20311', 'Tony Ruiz', 5, 240, 1865, 134],
  ['QTM84520', 'Keisha Moore', 4, 210, 1660, 242],
  ['BNX10477', 'Danny Kowalski', 3, 142, 1335, 97, { lastWeekMinutes: 1840, monthBonuses: 1000 }],
  ['PZE55102', 'Rosa Delgado', 2, 112, 1130, 58, { monthBonuses: 250 }],
  ['GVA73390', 'Marcus Noodles', 2, 85, 845, 200],
  ['WRD20984', 'Hannah Cole', 2, 80, 550, null],
  ['TFS66219', 'Victor Lindqvist', 2, 50, 0, null, { onLeave: true }],
  ['CXP31876', 'Jamal Brooks', 0, 20, 390, 22],
  ['HNE40912', 'Sofia Marin', 4, 190, 1210, null],
  ['JRT55870', 'Eli Grant', 3, 160, 980, null],
  ['MDS21794', 'Nadia Okafor', 2, 75, 720, null],
  ['PLW66103', 'Carlos Vega', 2, 70, 610, null],
  ['QAZ90127', 'Grace Lin', 2, 40, 330, null],
  ['RKV13458', 'Owen Pike', 2, 35, 290, null],
  ['SBT77231', 'Ty Russell', 1, 30, 480, null],
  ['UXN32065', 'Mia Ford', 1, 25, 0, null, { secondJob: true, lastWeekMinutes: 0 }],
  ['VCB48216', 'Leo Mart', 0, 12, 150, null],
  ['WEP59034', 'Ana Silva', 0, 5, 60, null],
];

const employees: Employee[] = seeds.map(([citizenid, name, grade, joined, week, shift, extra]) => {
  const rank = rankOf(grade);
  return {
    citizenid,
    name,
    grade,
    rank: rank.name,
    pay: rank.pay,
    isBoss: rank.isBoss,
    online: shift !== null,
    onDuty: shift !== null,
    onLeave: false,
    joinedAt: at(joined),
    shiftStartedAt: shift === null ? null : minutesAgo(shift),
    weekMinutes: week,
    lastWeekMinutes: Math.round(week * 1.2),
    monthBonuses: 0,
    ...extra,
  };
});

const requests: RequestItem[] = [
  {
    id: 41,
    kind: 'application',
    status: 'open',
    citizenid: 'MKD88140',
    name: 'Leon Hart',
    title: 'Application',
    message: "I spent six years at Hayes Autos doing engine swaps and bodywork, mostly imports. I can start this week and I'm free most evenings. I already have my own tools and a tow licence.",
    startDate: null,
    endDate: null,
    createdAt: minutesAgo(120),
    reviewedBy: null,
    reviewedAt: null,
    applicant: { phone: '555-0142', currentJob: null, workedHereBefore: false, online: true },
  },
  {
    id: 40,
    kind: 'application',
    status: 'open',
    citizenid: 'TRS20455',
    name: 'Priya Shah',
    title: 'Application',
    message: 'Can do nights and weekends.',
    startDate: null,
    endDate: null,
    createdAt: at(1, 19, 10),
    reviewedBy: null,
    reviewedAt: null,
    applicant: { phone: '555-0199', currentJob: 'Bean Machine', workedHereBefore: true, online: false },
  },
  {
    id: 39,
    kind: 'leave',
    status: 'open',
    citizenid: 'PZE55102',
    name: 'Rosa Delgado',
    title: 'Leave',
    message: 'Family visit in Paleto.',
    startDate: day(4),
    endDate: day(6),
    createdAt: at(1, 10, 12),
    reviewedBy: null,
    reviewedAt: null,
    applicant: null,
  },
  {
    id: 38,
    kind: 'report',
    status: 'open',
    citizenid: 'GVA73390',
    name: 'Marcus Noodles',
    title: 'Lift 2 keeps jamming',
    message: 'Lift 2 keeps jamming halfway up. Had to lower a Sultan by hand twice today.',
    startDate: null,
    endDate: null,
    createdAt: at(2, 18, 40),
    reviewedBy: null,
    reviewedAt: null,
    applicant: null,
  },
  {
    id: 31,
    kind: 'leave',
    status: 'approved',
    citizenid: 'PZE55102',
    name: 'Rosa Delgado',
    title: 'Leave',
    message: 'Moving house.',
    startDate: day(-31),
    endDate: day(-30),
    createdAt: at(36),
    reviewedBy: 'Keisha Moore',
    reviewedAt: at(35),
    applicant: null,
  },
];

const allAccess: Access = {
  overview: true,
  employees: true,
  bonus: true,
  manageStaff: true,
  requests: true,
  society: true,
  vehicles: true,
  announce: true,
  ranks: true,
  settings: true,
};

const noAccess: Access = {
  overview: false,
  employees: false,
  bonus: false,
  manageStaff: false,
  requests: false,
  society: false,
  vehicles: false,
  announce: false,
  ranks: false,
  settings: false,
};

const lsc = { name: 'mechanic', label: 'Los Santos Customs', type: 'mechanic', typeLabel: 'Mechanic shop', logoUrl: null };

function person(citizenid: string): Employee {
  const found = employees.find((entry) => entry.citizenid === citizenid);
  if (!found) throw new Error(`Mock employee ${citizenid} is missing`);
  return found;
}

function ownerSession(): OrgSession {
  const tony = person('LKR20311');

  return {
    mode: 'org',
    now: new Date(now).toISOString(),
    org: { ...lsc },
    me: {
      citizenid: tony.citizenid,
      name: tony.name,
      grade: tony.grade,
      rank: tony.rank,
      pay: tony.pay,
      isBoss: true,
      onDuty: true,
      shiftStartedAt: tony.shiftStartedAt,
      joinedAt: tony.joinedAt,
      weekMinutes: tony.weekMinutes,
      monthBonuses: 0,
    },
    access: { ...allAccess },
    features: { society: true, applications: true, leaves: true, reports: true, vehicles: true, announcements: true, duty: true, secondJobs: false },
    bosses: ['Tony Ruiz', 'Keisha Moore'],
    ranks: structuredClone(ranks),
    stats: { total: 18, onDuty: 6, weekMinutes: 12760, weekBonuses: 3500, fleet: 4 },
    employees: structuredClone(employees),
    requests: structuredClone(requests),
    society: {
      accountId: 'LSC-20418',
      balance: 184320,
      payroll: 6450,
      nextPaydayAt: inMinutes(18),
      transactions: [
        { id: 8, at: at(0, 14, 20), description: 'Repair invoice #4471, Adder', by: 'Rosa Delgado', amount: 2400 },
        { id: 7, at: at(0, 13, 5), description: 'Bonus to Danny Kowalski', by: 'Tony Ruiz', amount: -500 },
        { id: 6, at: at(0, 12, 0), description: 'Payday, 14 employees', by: 'Payroll', amount: -6450 },
        { id: 5, at: at(0, 11, 42), description: 'Tow job, Strawberry Ave', by: 'Marcus Noodles', amount: 650 },
        { id: 4, at: at(1, 16, 0), description: 'Bought Flatbed, plate LSC 03', by: 'Keisha Moore', amount: -35000 },
        { id: 3, at: at(1, 10, 0), description: 'Deposit, weekend takings', by: 'Tony Ruiz', amount: 40000 },
        { id: 2, at: at(2, 15, 0), description: 'Custom paint, Sultan RS', by: 'Danny Kowalski', amount: 5800 },
        { id: 1, at: at(2, 9, 0), description: 'Withdrawal, parts run', by: 'Keisha Moore', amount: -3000 },
      ],
    },
    vehicles: {
      catalogue: [
        { model: 'towtruck', label: 'Tow Truck', use: 'Service', minGrade: 0, minRank: 'Apprentice', price: 0 },
        { model: 'flatbed', label: 'Flatbed', use: 'Service', minGrade: 2, minRank: 'Mechanic', price: 35000 },
        { model: 'burrito', label: 'Utility Van', use: 'Mobile repair', minGrade: 2, minRank: 'Mechanic', price: 28000 },
        { model: 'wrecker', label: 'Heavy Wrecker', use: 'Recovery', minGrade: 3, minRank: 'Lead mechanic', price: 200000 },
      ],
      fleet: [
        { plate: 'LSC 03', model: 'flatbed', label: 'Flatbed', boughtBy: 'Keisha Moore', boughtAt: at(1, 16, 0) },
        { plate: 'LSC 02', model: 'burrito', label: 'Utility Van', boughtBy: 'Tony Ruiz', boughtAt: at(22) },
        { plate: 'LSC 01', model: 'towtruck', label: 'Tow Truck', boughtBy: 'Tony Ruiz', boughtAt: at(245) },
        { plate: 'LSC 00', model: 'towtruck', label: 'Tow Truck', boughtBy: 'Tony Ruiz', boughtAt: at(245) },
      ],
    },
    announcements: [
      { id: 4, title: 'Flatbed is ours', message: 'LSC 03 is in the garage. Mechanics and up can take it out. Bring it back with a full tank.', author: 'Keisha Moore', createdAt: at(1, 17, 0) },
      { id: 3, title: "Benny's parts order lands Thursday", message: 'Turbo kits and brake sets are back in stock from Thursday. Take customer orders now, quote the old prices.', author: 'Keisha Moore', createdAt: at(2, 9, 0) },
      { id: 2, title: 'Night shift needs two more', message: 'From next week we stay open until 4am Friday and Saturday. Put your name down with Keisha if you want the hours. Night shifts pay a $200 bonus on top.', author: 'Tony Ruiz', createdAt: at(6) },
      { id: 1, title: 'Clock in at the terminal', message: "Hours only count while you're on duty. Paydays come from your logged hours, so clock in when you arrive and out when you leave.", author: 'Tony Ruiz', createdAt: at(20) },
    ],
    myRequests: [],
    myJobs: [{ name: 'mechanic', label: 'Los Santos Customs', rank: 'Owner', pay: 900, since: tony.joinedAt, isMain: true, onDuty: true }],
    hireRadius: 10,
    logoHosts: ['cdn.fivemesh.io'],
    limits: { bonus: 50000, message: 1000, title: 120, reason: 255 },
  };
}

function staffSession(withJobs: boolean): OrgSession {
  const base = ownerSession();
  const rosa = person('PZE55102');

  return {
    ...base,
    me: {
      citizenid: rosa.citizenid,
      name: rosa.name,
      grade: rosa.grade,
      rank: rosa.rank,
      pay: rosa.pay,
      isBoss: false,
      onDuty: true,
      shiftStartedAt: rosa.shiftStartedAt,
      joinedAt: rosa.joinedAt,
      weekMinutes: rosa.weekMinutes,
      monthBonuses: rosa.monthBonuses,
    },
    access: { ...noAccess },
    features: { ...base.features, secondJobs: withJobs },
    stats: null,
    employees: null,
    requests: null,
    society: null,
    vehicles: null,
    myRequests: structuredClone(requests.filter((request) => request.citizenid === rosa.citizenid)),
    myJobs: [
      { name: 'mechanic', label: 'Los Santos Customs', rank: 'Mechanic', pay: 400, since: rosa.joinedAt, isMain: true, onDuty: true },
      ...(withJobs
        ? [
            { name: 'beanmachine', label: 'Bean Machine', rank: 'Barista', pay: 180, since: at(32), isMain: false, onDuty: false },
            { name: 'downtowncab', label: 'Downtown Cab Co.', rank: 'Driver', pay: 220, since: at(6), isMain: false, onDuty: false },
          ]
        : []),
    ],
  };
}

const gangRanks: GangRank[] = [
  { grade: 0, name: 'Affiliate', isBoss: false },
  { grade: 1, name: 'Hitta', isBoss: false },
  { grade: 2, name: 'Soldier', isBoss: false },
  { grade: 3, name: 'Lieutenant', isBoss: false },
  { grade: 4, name: 'Shotcaller', isBoss: false },
  { grade: 5, name: 'Big Homie', isBoss: true },
];

const zones: Zone[] = [
  { id: 'davis', label: 'Davis' },
  { id: 'strawberry', label: 'Strawberry' },
  { id: 'rancho', label: 'Rancho' },
  { id: 'chamberlain', label: 'Chamberlain Hills' },
  { id: 'vespucci', label: 'Vespucci' },
  { id: 'mirrorpark', label: 'Mirror Park' },
  { id: 'sandy', label: 'Sandy Shores' },
];

const colours: MapColour[] = [
  { id: 0, label: 'White', hex: '#fafafa' },
  { id: 1, label: 'Red', hex: '#e03232' },
  { id: 2, label: 'Green', hex: '#72cc72' },
  { id: 5, label: 'Yellow', hex: '#eec64e' },
  { id: 7, label: 'Purple', hex: '#9a6ab6' },
  { id: 11, label: 'Cyan', hex: '#5fd0c9' },
  { id: 27, label: 'Light blue', hex: '#8ec1f0' },
  { id: 47, label: 'Orange', hex: '#f49b29' },
];

const streetDefaults: Record<string, string[]> = {
  '0': ['tag_wall', 'homeland_bonus'],
  '1': ['tag_wall', 'homeland_bonus', 'racket_claim'],
  '2': ['tag_wall', 'homeland_bonus', 'racket_claim', 'racket_launder', 'vinscratch_perfect'],
  '3': ['tag_wall', 'homeland_bonus', 'racket_claim', 'racket_launder', 'racket_raid', 'vinscratch_perfect', 'vault_view', 'turf_set'],
  '4': ['tag_wall', 'homeland_bonus', 'racket_claim', 'racket_launder', 'racket_raid', 'vinscratch_perfect', 'vault_view', 'vault_withdraw', 'vault_audit', 'turf_set'],
};

function gangSession(): GangSession {
  return {
    mode: 'gang',
    now: new Date(now).toISOString(),
    gang: { name: 'davis_kings', label: 'Davis Avenue Kings', archetype: 'street', archetypeLabel: 'Street gang', foundedAt: at(13) },
    me: { citizenid: 'RXM30217', name: 'Andre Wallace', grade: 5, rank: 'Big Homie', isBoss: true, isFounder: true, permissions: [] },
    ranks: structuredClone(gangRanks),
    members: [
      { citizenid: 'RXM30217', name: 'Andre Wallace', grade: 5, rank: 'Big Homie', isBoss: true, online: true, joinedAt: at(13) },
      { citizenid: 'HKW49120', name: 'Darnell Price', grade: 4, rank: 'Shotcaller', isBoss: false, online: true, joinedAt: at(13) },
      { citizenid: 'ZPL66031', name: 'Tasha Greene', grade: 3, rank: 'Lieutenant', isBoss: false, online: false, joinedAt: at(12) },
      { citizenid: 'QFT10388', name: 'Jerome Banks', grade: 2, rank: 'Soldier', isBoss: false, online: true, joinedAt: at(10) },
      { citizenid: 'BNM22841', name: 'Lil Remy Carter', grade: 2, rank: 'Soldier', isBoss: false, online: false, joinedAt: at(7) },
      { citizenid: 'CVX93502', name: 'Kenny Ortiz', grade: 1, rank: 'Hitta', isBoss: false, online: true, joinedAt: at(4) },
      { citizenid: 'DLK11473', name: 'Malik Johnson', grade: 0, rank: 'Affiliate', isBoss: false, online: false, joinedAt: at(1) },
    ],
    inviteRadius: 8,
    permissionCatalog: [
      { id: 'tag_wall', label: 'Tag walls', group: 'Streets' },
      { id: 'homeland_bonus', label: 'Home turf payout bonus', group: 'Streets' },
      { id: 'racket_claim', label: 'Claim businesses', group: 'Business' },
      { id: 'racket_launder', label: 'Run laundering', group: 'Business' },
      { id: 'racket_raid', label: 'Lead raids on rivals', group: 'Business' },
      { id: 'vinscratch_perfect', label: 'Perfect VIN scrubs', group: 'Business' },
      { id: 'vault_view', label: 'See the vault', group: 'Vault' },
      { id: 'vault_withdraw', label: 'Withdraw from the vault', group: 'Vault' },
      { id: 'vault_audit', label: 'See vault history', group: 'Vault' },
      { id: 'turf_set', label: 'Move home turf and HQ', group: 'Leadership' },
      { id: 'gang_invite', label: 'Invite players', group: 'Leadership' },
    ],
    permissions: {
      '0': ['tag_wall', 'homeland_bonus'],
      '1': ['tag_wall', 'homeland_bonus', 'racket_claim'],
      '2': ['tag_wall', 'homeland_bonus', 'racket_claim'],
      '3': ['tag_wall', 'homeland_bonus', 'racket_claim', 'racket_launder', 'vault_view', 'vault_audit', 'gang_invite'],
      '4': ['tag_wall', 'homeland_bonus', 'racket_claim', 'racket_launder', 'racket_raid', 'vinscratch_perfect', 'vault_view', 'vault_withdraw', 'vault_audit', 'turf_set', 'gang_invite'],
    },
    vault: {
      balance: 612400,
      canSee: true,
      canWithdraw: true,
      canSeeHistory: true,
      history: [
        { id: 4, at: at(0, 1, 12), what: 'Deposit at the charterer', who: 'Jerome Banks', amount: 48500 },
        { id: 3, at: at(1, 22, 0), what: 'Moved HQ to Grove Street garage', who: 'Andre Wallace', amount: -25000 },
        { id: 2, at: at(2, 20, 0), what: 'Withdrawal', who: 'Darnell Price', amount: -10000 },
        { id: 1, at: at(4, 23, 0), what: 'Deposit at the charterer', who: 'Tasha Greene', amount: 91200 },
      ],
    },
    turf: { zone: 'davis', zones: structuredClone(zones), cost: 50000, cooldownHours: 24, cooldownEndsAt: null, canMove: true },
    hq: { label: 'Grove Street garage, Davis', movedAt: at(1, 22, 0), cost: 25000, cooldownEndsAt: inMinutes(580), canMove: true },
    archetypes: [
      { id: 'street', label: 'Street gang', summary: 'Affiliate to Big Homie. Tag walls, home turf bonus, perfect VIN scrubs.', ranks: 6, price: 0, current: true },
      { id: 'mc', label: 'Motorcycle Club', summary: 'Hangaround to President, 7 ranks. Premium chop parts, clones that keep the owner, bike formations.', ranks: 7, price: 750000, current: false },
      { id: 'mafia', label: 'Mafia', summary: 'Associate to Don. Buy business fronts, run rackets and laundering.', ranks: 6, price: 1000000, current: false },
      { id: 'cartel', label: 'Cartel', summary: 'Halcón to Patrón. Operate the lab and craft criminal tools.', ranks: 6, price: 1000000, current: false },
    ],
    upgrade: { ageDays: 13, minAgeDays: 7, members: 7, minMembers: 5, vault: 612400, minVault: 500000, lastChangeAt: null, cooldownDays: 14, cooldownEndsAt: null },
  };
}

function ladder(names: string[]): GangRank[] {
  return names.map((name, grade) => ({ grade, name, isBoss: grade === names.length - 1 }));
}

const adminMembers: Record<string, AdminMember[]> = {
  davis_kings: [
    { citizenid: 'RXM30217', name: 'Andre Wallace', grade: 5, online: true },
    { citizenid: 'HKW49120', name: 'Darnell Price', grade: 4, online: true },
    { citizenid: 'ZPL66031', name: 'Tasha Greene', grade: 3, online: false },
    { citizenid: 'QFT10388', name: 'Jerome Banks', grade: 2, online: true },
    { citizenid: 'BNM22841', name: 'Lil Remy Carter', grade: 2, online: false },
    { citizenid: 'CVX93502', name: 'Kenny Ortiz', grade: 1, online: true },
    { citizenid: 'DLK11473', name: 'Malik Johnson', grade: 0, online: false },
  ],
};

function adminSession(): AdminSession {
  return {
    mode: 'gangAdmin',
    now: new Date(now).toISOString(),
    admin: { name: 'Kai Turner', rank: 'Admin' },
    gangs: [
      { name: 'ballas', label: 'Ballas', archetype: 'street', homeTurf: 'davis', blipColor: 7, members: 12, founderName: 'Big Smoke', foundedAt: at(120) },
      { name: 'vagos', label: 'Vagos', archetype: 'street', homeTurf: 'rancho', blipColor: 5, members: 9, founderName: 'Luis Mendoza', foundedAt: at(98) },
      { name: 'lostmc', label: 'The Lost MC', archetype: 'mc', homeTurf: 'sandy', blipColor: 1, members: 6, founderName: null, foundedAt: at(80) },
      { name: 'davis_kings', label: 'Davis Avenue Kings', archetype: 'street', homeTurf: 'davis', blipColor: 0, members: 7, founderName: 'Andre Wallace', foundedAt: at(13) },
      { name: 'vespucci_saints', label: 'Vespucci Saints', archetype: 'street', homeTurf: 'vespucci', blipColor: 27, members: 4, founderName: 'Nico Bell', foundedAt: at(6) },
    ],
    maxGangs: 8,
    nameLength: { min: 3, max: 32 },
    archetypes: [
      { id: 'street', label: 'Street gang', ranks: structuredClone(gangRanks) },
      { id: 'mc', label: 'Motorcycle Club', ranks: ladder(['Hangaround', 'Prospect', 'Patched', 'Sergeant-at-Arms', 'Road Captain', 'Vice President', 'President']) },
      { id: 'mafia', label: 'Mafia', ranks: ladder(['Associate', 'Soldier', 'Caporegime', 'Consigliere', 'Underboss', 'Don']) },
      { id: 'cartel', label: 'Cartel', ranks: ladder(['Halcón', 'Mula', 'Sicario', 'Lugarteniente', 'Jefe de Plaza', 'Patrón']) },
    ],
    zones: structuredClone(zones),
    colours: structuredClone(colours),
    onlinePlayers: [
      { serverId: 12, citizenid: 'TSM44120', name: 'Trey Simmons', gangLabel: null },
      { serverId: 18, citizenid: 'LMV90233', name: 'Luis Mendoza', gangLabel: 'Vagos' },
      { serverId: 21, citizenid: 'ORB55012', name: 'Omar Bashir', gangLabel: null },
    ],
  };
}

function applySession(): ApplySession {
  return {
    mode: 'apply',
    now: new Date(now).toISOString(),
    org: { ...lsc },
    reviewers: ['Tony Ruiz', 'Keisha Moore'],
    startingRank: 'Apprentice',
    startingPay: 250,
    staff: 18,
    maxLength: 1000,
    pending: null,
  };
}

function charterSession(): CharterSession {
  return {
    mode: 'charter',
    now: new Date(now).toISOString(),
    price: 250000,
    carried: 312000,
    slotsUsed: 5,
    maxSlots: 8,
    bossRank: 'Big Homie',
    zones: structuredClone(zones),
    colours: structuredClone(colours),
    nameLength: { min: 3, max: 32 },
  };
}

let org = ownerSession();
let gang = gangSession();
let admin = adminSession();
let apply = applySession();

export function sessionFor(scene: string): Session {
  switch (scene) {
    case 'staff':
      org = staffSession(false);
      return structuredClone(org);
    case 'jobs':
      org = staffSession(true);
      return structuredClone(org);
    case 'empty':
      org = { ...ownerSession(), requests: requests.filter((request) => request.status !== 'open') };
      return structuredClone(org);
    case 'gang':
      gang = gangSession();
      return structuredClone(gang);
    case 'gangAdmin':
      admin = adminSession();
      return structuredClone(admin);
    case 'apply':
      apply = applySession();
      return structuredClone(apply);
    case 'charter':
      return charterSession();
    default:
      org = ownerSession();
      return structuredClone(org);
  }
}

function employee(citizenid: string): Employee | undefined {
  return org.employees?.find((entry) => entry.citizenid === citizenid);
}

function recount(): void {
  for (const rank of org.ranks) rank.people = org.employees?.filter((entry) => entry.grade === rank.grade).length ?? 0;
  if (org.stats && org.employees) org.stats.total = org.employees.length;
}

function ledger(description: string, amount: number): void {
  if (!org.society) return;

  org.society.balance += amount;
  org.society.transactions.unshift({ id: Date.now(), at: new Date().toISOString(), description, by: org.me.name, amount });
}

export const handlers: MockHandlers = {
  close: () => ({ ok: true }),
  setDuty: ({ onDuty }) => {
    org.me.onDuty = onDuty;
    org.me.shiftStartedAt = onDuty ? new Date().toISOString() : null;
    return ok(org);
  },
  nearbyPlayers: () => [
    { serverId: 4, citizenid: 'MKD88140', name: 'Leon Hart', distance: 2, job: null, appliedAt: minutesAgo(120) },
    { serverId: 9, citizenid: 'AWF30981', name: 'Ava Whitfield', distance: 6, job: 'Bean Machine', appliedAt: null },
    { serverId: 15, citizenid: 'ORB55012', name: 'Omar Bashir', distance: 9, job: null, appliedAt: null },
  ],
  hire: ({ citizenid }) => {
    if (employee(citizenid)) return fail('They already work here.');

    return ok(org);
  },
  fire: ({ citizenid }) => {
    org.employees = org.employees?.filter((entry) => entry.citizenid !== citizenid) ?? null;
    recount();
    return ok(org);
  },
  setGrade: ({ citizenid, grade }) => {
    const target = employee(citizenid);
    if (!target) return fail('That person no longer works here.');

    const rank = rankOf(grade);
    Object.assign(target, { grade, rank: rank.name, pay: rank.pay });
    recount();
    return ok(org);
  },
  giveBonus: ({ citizenid, amount }) => {
    const target = employee(citizenid);
    if (!target) return fail('That person no longer works here.');
    if (org.society && org.society.balance < amount) return fail(`Not enough in the society account. It holds $${org.society.balance.toLocaleString('en-US')}.`);

    target.monthBonuses += amount;
    ledger(`Bonus to ${target.name}`, -amount);
    return ok(org);
  },
  answerRequest: ({ id, approve }) => {
    const request = org.requests?.find((entry) => entry.id === id);
    if (!request) return fail('That request was already answered.');

    Object.assign(request, { status: approve ? 'approved' : 'declined', reviewedBy: org.me.name, reviewedAt: new Date().toISOString() });
    return ok(org);
  },
  deposit: ({ amount, note }) => {
    ledger(note ? `Deposit, ${note}` : 'Deposit', amount);
    return ok(org);
  },
  withdraw: ({ amount, note }) => {
    if (!org.society || org.society.balance < amount) return fail('Not enough in the society account.');

    ledger(note ? `Withdrawal, ${note}` : 'Withdrawal', -amount);
    return ok(org);
  },
  saveRank: ({ grade, pay, permissions }) => {
    const rank = org.ranks.find((entry) => entry.grade === grade);
    if (!rank) return fail('That rank no longer exists.');

    Object.assign(rank, { pay, permissions });
    return ok(org);
  },
  buyVehicle: ({ model }) => {
    const vehicle = org.vehicles?.catalogue.find((entry) => entry.model === model);
    if (!vehicle || !org.vehicles) return fail('That vehicle is not for sale.');
    if ((org.society?.balance ?? 0) < vehicle.price) return fail('Not enough in the society account.');

    const plate = `LSC ${org.vehicles.fleet.length.toString().padStart(2, '0')}`;
    org.vehicles.fleet.unshift({ plate, model, label: vehicle.label, boughtBy: org.me.name, boughtAt: new Date().toISOString() });
    if (vehicle.price > 0) ledger(`Bought ${vehicle.label}, plate ${plate}`, -vehicle.price);
    if (org.stats) org.stats.fleet = org.vehicles.fleet.length;
    return ok(org);
  },
  postAnnouncement: ({ title, message }) => {
    org.announcements.unshift({ id: Date.now(), title, message, author: org.me.name, createdAt: new Date().toISOString() });
    return ok(org);
  },
  saveLogo: ({ url }) => {
    org.org.logoUrl = url || null;
    return ok(org);
  },
  setFeature: ({ feature, enabled }) => {
    org.features[feature] = enabled;
    return ok(org);
  },
  sendLeave: ({ from, until, reason }) => {
    org.myRequests.unshift({
      id: Date.now(),
      kind: 'leave',
      status: 'open',
      citizenid: org.me.citizenid,
      name: org.me.name,
      title: 'Leave',
      message: reason,
      startDate: from,
      endDate: until,
      createdAt: new Date().toISOString(),
      reviewedBy: null,
      reviewedAt: null,
      applicant: null,
    });
    return ok(org);
  },
  sendReport: ({ title, message }) => {
    org.myRequests.unshift({
      id: Date.now(),
      kind: 'report',
      status: 'open',
      citizenid: org.me.citizenid,
      name: org.me.name,
      title,
      message,
      startDate: null,
      endDate: null,
      createdAt: new Date().toISOString(),
      reviewedBy: null,
      reviewedAt: null,
      applicant: null,
    });
    return ok(org);
  },
  makeMainJob: ({ name }) => {
    org.myJobs = org.myJobs.map((job) => ({ ...job, isMain: job.name === name }));
    return ok(org);
  },
  leaveJob: ({ name }) => {
    org.myJobs = org.myJobs.filter((job) => job.name !== name);
    return ok(org);
  },

  'gang:nearby': () => [
    { serverId: 12, name: 'Trey Simmons', distance: 3, gangLabel: null },
    { serverId: 18, name: 'Luis Mendoza', distance: 7, gangLabel: 'Vagos' },
  ],
  'gang:invite': () => ok(gang),
  'gang:kick': ({ citizenid }) => {
    gang.members = gang.members.filter((member) => member.citizenid !== citizenid);
    return ok(gang);
  },
  'gang:passLeadership': () => fail('They need to be online and standing near you.'),
  'gang:leave': () => ({ ok: true }),
  'gang:disband': () => ({ ok: true }),
  'gang:savePermissions': ({ permissions }) => {
    gang.permissions = permissions;
    return ok(gang);
  },
  'gang:resetPermissions': () => {
    gang.permissions = structuredClone(streetDefaults);
    return ok(gang);
  },
  'gang:withdraw': ({ amount }) => {
    if (amount > gang.vault.balance) return fail('The vault does not hold that much.');

    gang.vault.balance -= amount;
    gang.vault.history.unshift({ id: Date.now(), at: new Date().toISOString(), what: 'Withdrawal', who: gang.me.name, amount: -amount });
    return ok(gang);
  },
  'gang:moveTurf': ({ zone }) => {
    gang.turf.zone = zone;
    gang.turf.cooldownEndsAt = inMinutes(1440);
    gang.vault.balance -= gang.turf.cost;
    return ok(gang);
  },
  'gang:pickHq': () => ({ ok: false, error: 'You can move HQ again once the wait is over.' }),
  'gang:upgrade': () => fail('The vault needs to cover the price first.'),

  'admin:members': ({ name }) => structuredClone(adminMembers[name] ?? []),
  'admin:create': ({ label, archetype, homeTurf, blipColor }) => {
    const name = label.toLowerCase().replace(/[^a-z0-9]+/g, '_');
    admin.gangs.push({ name, label, archetype, homeTurf: homeTurf || null, blipColor, members: 0, founderName: null, foundedAt: new Date().toISOString() });
    return ok(admin);
  },
  'admin:save': ({ name, label, archetype, homeTurf, blipColor }) => {
    const target = admin.gangs.find((entry) => entry.name === name);
    if (!target) return fail('That gang no longer exists.');

    Object.assign(target, { label, archetype, homeTurf: homeTurf || null, blipColor });
    return ok(admin);
  },
  'admin:delete': ({ name }) => {
    admin.gangs = admin.gangs.filter((entry) => entry.name !== name);
    return ok(admin);
  },
  'admin:assign': ({ name, citizenid, grade }) => {
    const list = (adminMembers[name] ??= []);
    const existing = list.find((member) => member.citizenid === citizenid);
    const player = admin.onlinePlayers.find((entry) => entry.citizenid === citizenid);

    if (existing) existing.grade = grade;
    else list.push({ citizenid, name: player?.name ?? citizenid, grade, online: true });

    const target = admin.gangs.find((entry) => entry.name === name);
    if (target) target.members = list.length;
    return ok(admin);
  },
  'admin:remove': ({ name, citizenid }) => {
    adminMembers[name] = (adminMembers[name] ?? []).filter((member) => member.citizenid !== citizenid);
    const target = admin.gangs.find((entry) => entry.name === name);
    if (target) target.members = adminMembers[name]?.length ?? 0;
    return ok(admin);
  },

  'apply:send': ({ message }) => {
    apply.pending = {
      id: Date.now(),
      kind: 'application',
      status: 'open',
      citizenid: 'MKD88140',
      name: 'Leon Hart',
      title: 'Application',
      message,
      startDate: null,
      endDate: null,
      createdAt: new Date().toISOString(),
      reviewedBy: null,
      reviewedAt: null,
      applicant: null,
    };
    return ok(apply);
  },
  'charter:send': () => ({ ok: true }),
};
