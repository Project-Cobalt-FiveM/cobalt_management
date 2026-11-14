import type { MockHandlers } from './nui';
import { toDay } from './format';
import type {
  Access,
  AdminSession,
  ApplySession,
  CharterSession,
  Employee,
  GangMember,
  GangPermission,
  GangRank,
  GangSession,
  Iso,
  JobSession,
  Rank,
  RequestItem,
  Result,
  Session,
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

function ownerSession(): JobSession {
  const tony = person('LKR20311');

  return {
    mode: 'job',
    now: new Date(now).toISOString(),
    job: { ...lsc },
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

function staffSession(withJobs: boolean): JobSession {
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
  { grade: 0, name: 'Recruit', isBoss: false },
  { grade: 1, name: 'Soldier', isBoss: false },
  { grade: 2, name: 'Lieutenant', isBoss: false },
  { grade: 3, name: 'Underboss', isBoss: false },
  { grade: 4, name: 'Boss', isBoss: true },
];

const builtInRanks: GangRank[] = [
  { grade: 0, name: 'Recruit', isBoss: false },
  { grade: 1, name: 'Enforcer', isBoss: false },
  { grade: 2, name: 'Shot Caller', isBoss: false },
  { grade: 3, name: 'Boss', isBoss: true },
];

const defaultPermissions: Record<string, GangPermission[]> = {
  '0': ['vault_deposit', 'gang_invite'],
  '1': ['vault_deposit', 'gang_invite'],
  '2': ['vault_view', 'vault_deposit', 'gang_invite'],
  '3': ['vault_view', 'vault_deposit', 'vault_withdraw', 'vault_audit', 'gang_invite'],
};

function gangSession(): GangSession {
  return {
    mode: 'gang',
    now: new Date(now).toISOString(),
    gang: { name: 'davis_kings', label: 'Davis Avenue Kings', foundedAt: at(13) },
    me: {
      citizenid: 'RXM30217',
      name: 'Andre Wallace',
      grade: 4,
      rank: 'Boss',
      isBoss: true,
      isFounder: true,
      permissions: ['vault_view', 'vault_deposit', 'vault_withdraw', 'vault_audit', 'gang_invite'],
    },
    ranks: structuredClone(gangRanks),
    members: [
      { citizenid: 'RXM30217', name: 'Andre Wallace', grade: 4, rank: 'Boss', isBoss: true, online: true, joinedAt: at(13) },
      { citizenid: 'HKW49120', name: 'Darnell Price', grade: 3, rank: 'Underboss', isBoss: false, online: true, joinedAt: at(13) },
      { citizenid: 'ZPL66031', name: 'Tasha Greene', grade: 2, rank: 'Lieutenant', isBoss: false, online: false, joinedAt: at(12) },
      { citizenid: 'QFT10388', name: 'Jerome Banks', grade: 1, rank: 'Soldier', isBoss: false, online: true, joinedAt: at(10) },
      { citizenid: 'BNM22841', name: 'Lil Remy Carter', grade: 1, rank: 'Soldier', isBoss: false, online: false, joinedAt: at(7) },
      { citizenid: 'CVX93502', name: 'Kenny Ortiz', grade: 0, rank: 'Recruit', isBoss: false, online: true, joinedAt: at(4) },
      { citizenid: 'DLK11473', name: 'Malik Johnson', grade: 0, rank: 'Recruit', isBoss: false, online: false, joinedAt: at(1) },
    ],
    inviteRadius: 8,
    permissionCatalog: [
      { id: 'vault_view', label: 'See the vault' },
      { id: 'vault_deposit', label: 'Deposit into the vault' },
      { id: 'vault_withdraw', label: 'Withdraw from the vault' },
      { id: 'vault_audit', label: 'See vault history' },
      { id: 'gang_invite', label: 'Invite players' },
    ],
    permissions: structuredClone(defaultPermissions),
    vault: {
      balance: 612400,
      canSee: true,
      canDeposit: true,
      canWithdraw: true,
      canSeeHistory: true,
      history: [
        { id: 3, at: at(0, 1, 12), what: 'Deposit at the charterer', who: 'Jerome Banks', amount: 48500 },
        { id: 2, at: at(2, 20, 0), what: 'Withdrawal', who: 'Darnell Price', amount: -10000 },
        { id: 1, at: at(4, 23, 0), what: 'Deposit at the charterer', who: 'Tasha Greene', amount: 91200 },
      ],
    },
  };
}

const adminMembers: Record<string, GangMember[]> = {
  davis_kings: gangSession().members,
};

function adminSession(): AdminSession {
  return {
    mode: 'gangAdmin',
    now: new Date(now).toISOString(),
    admin: { name: 'Kai Turner', rank: 'Admin' },
    gangs: [
      { name: 'ballas', label: 'Ballas', ranks: structuredClone(builtInRanks), members: 12, founderName: null, foundedAt: at(120) },
      { name: 'vagos', label: 'Vagos', ranks: structuredClone(builtInRanks), members: 9, founderName: null, foundedAt: at(98) },
      { name: 'lostmc', label: 'The Lost MC', ranks: structuredClone(builtInRanks), members: 6, founderName: null, foundedAt: at(80) },
      { name: 'davis_kings', label: 'Davis Avenue Kings', ranks: structuredClone(gangRanks), members: 7, founderName: 'Andre Wallace', foundedAt: at(13) },
      { name: 'vespucci_saints', label: 'Vespucci Saints', ranks: structuredClone(gangRanks), members: 4, founderName: 'Nico Bell', foundedAt: at(6) },
    ],
    maxGangs: 8,
    nameLength: { min: 3, max: 32 },
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
    job: { ...lsc },
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
    bossRank: 'Boss',
    nameLength: { min: 3, max: 32 },
  };
}

let job = ownerSession();
let gang = gangSession();
let admin = adminSession();
let apply = applySession();

export function sessionFor(scene: string): Session {
  switch (scene) {
    case 'staff':
      job = staffSession(false);
      return structuredClone(job);
    case 'jobs':
      job = staffSession(true);
      return structuredClone(job);
    case 'empty':
      job = { ...ownerSession(), requests: requests.filter((request) => request.status !== 'open') };
      return structuredClone(job);
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
      job = ownerSession();
      return structuredClone(job);
  }
}

function employee(citizenid: string): Employee | undefined {
  return job.employees?.find((entry) => entry.citizenid === citizenid);
}

function recount(): void {
  for (const rank of job.ranks) rank.people = job.employees?.filter((entry) => entry.grade === rank.grade).length ?? 0;
  if (job.stats && job.employees) job.stats.total = job.employees.length;
}

function ledger(description: string, amount: number): void {
  if (!job.society) return;

  job.society.balance += amount;
  job.society.transactions.unshift({ id: Date.now(), at: new Date().toISOString(), description, by: job.me.name, amount });
}

export const handlers: MockHandlers = {
  close: () => ({ ok: true }),
  setDuty: ({ onDuty }) => {
    job.me.onDuty = onDuty;
    job.me.shiftStartedAt = onDuty ? new Date().toISOString() : null;
    return ok(job);
  },
  nearbyPlayers: () => [
    { serverId: 4, citizenid: 'MKD88140', name: 'Leon Hart', distance: 2, job: null, appliedAt: minutesAgo(120) },
    { serverId: 9, citizenid: 'AWF30981', name: 'Ava Whitfield', distance: 6, job: 'Bean Machine', appliedAt: null },
    { serverId: 15, citizenid: 'ORB55012', name: 'Omar Bashir', distance: 9, job: null, appliedAt: null },
  ],
  hire: ({ citizenid }) => {
    if (employee(citizenid)) return fail('They already work here.');

    return ok(job);
  },
  fire: ({ citizenid }) => {
    job.employees = job.employees?.filter((entry) => entry.citizenid !== citizenid) ?? null;
    recount();
    return ok(job);
  },
  setGrade: ({ citizenid, grade }) => {
    const target = employee(citizenid);
    if (!target) return fail('That person no longer works here.');

    const rank = rankOf(grade);
    Object.assign(target, { grade, rank: rank.name, pay: rank.pay });
    recount();
    return ok(job);
  },
  giveBonus: ({ citizenid, amount }) => {
    const target = employee(citizenid);
    if (!target) return fail('That person no longer works here.');
    if (job.society && job.society.balance < amount) return fail(`Not enough in the society account. It holds $${job.society.balance.toLocaleString('en-US')}.`);

    target.monthBonuses += amount;
    ledger(`Bonus to ${target.name}`, -amount);
    return ok(job);
  },
  answerRequest: ({ id, approve }) => {
    const request = job.requests?.find((entry) => entry.id === id);
    if (!request) return fail('That request was already answered.');

    Object.assign(request, { status: approve ? 'approved' : 'declined', reviewedBy: job.me.name, reviewedAt: new Date().toISOString() });
    return ok(job);
  },
  deposit: ({ amount, note }) => {
    ledger(note ? `Deposit, ${note}` : 'Deposit', amount);
    return ok(job);
  },
  withdraw: ({ amount, note }) => {
    if (!job.society || job.society.balance < amount) return fail('Not enough in the society account.');

    ledger(note ? `Withdrawal, ${note}` : 'Withdrawal', -amount);
    return ok(job);
  },
  saveRank: ({ grade, pay, permissions }) => {
    const rank = job.ranks.find((entry) => entry.grade === grade);
    if (!rank) return fail('That rank no longer exists.');

    Object.assign(rank, { pay, permissions });
    return ok(job);
  },
  buyVehicle: ({ model }) => {
    const vehicle = job.vehicles?.catalogue.find((entry) => entry.model === model);
    if (!vehicle || !job.vehicles) return fail('That vehicle is not for sale.');
    if ((job.society?.balance ?? 0) < vehicle.price) return fail('Not enough in the society account.');

    const plate = `LSC ${job.vehicles.fleet.length.toString().padStart(2, '0')}`;
    job.vehicles.fleet.unshift({ plate, model, label: vehicle.label, boughtBy: job.me.name, boughtAt: new Date().toISOString() });
    if (vehicle.price > 0) ledger(`Bought ${vehicle.label}, plate ${plate}`, -vehicle.price);
    if (job.stats) job.stats.fleet = job.vehicles.fleet.length;
    return ok(job);
  },
  postAnnouncement: ({ title, message }) => {
    job.announcements.unshift({ id: Date.now(), title, message, author: job.me.name, createdAt: new Date().toISOString() });
    return ok(job);
  },
  saveLogo: ({ url }) => {
    job.job.logoUrl = url || null;
    return ok(job);
  },
  setFeature: ({ feature, enabled }) => {
    job.features[feature] = enabled;
    return ok(job);
  },
  sendLeave: ({ from, until, reason }) => {
    job.myRequests.unshift({
      id: Date.now(),
      kind: 'leave',
      status: 'open',
      citizenid: job.me.citizenid,
      name: job.me.name,
      title: 'Leave',
      message: reason,
      startDate: from,
      endDate: until,
      createdAt: new Date().toISOString(),
      reviewedBy: null,
      reviewedAt: null,
      applicant: null,
    });
    return ok(job);
  },
  sendReport: ({ title, message }) => {
    job.myRequests.unshift({
      id: Date.now(),
      kind: 'report',
      status: 'open',
      citizenid: job.me.citizenid,
      name: job.me.name,
      title,
      message,
      startDate: null,
      endDate: null,
      createdAt: new Date().toISOString(),
      reviewedBy: null,
      reviewedAt: null,
      applicant: null,
    });
    return ok(job);
  },
  makeMainJob: ({ name }) => {
    job.myJobs = job.myJobs.map((entry) => ({ ...entry, isMain: entry.name === name }));
    return ok(job);
  },
  leaveJob: ({ name }) => {
    job.myJobs = job.myJobs.filter((entry) => entry.name !== name);
    return ok(job);
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
    gang.permissions = structuredClone(defaultPermissions);
    return ok(gang);
  },
  'gang:withdraw': ({ amount }) => {
    if (amount > gang.vault.balance) return fail('The vault does not hold that much.');

    gang.vault.balance -= amount;
    gang.vault.history.unshift({ id: Date.now(), at: new Date().toISOString(), what: 'Withdrawal', who: gang.me.name, amount: -amount });
    return ok(gang);
  },

  'admin:members': ({ name }) => structuredClone(adminMembers[name] ?? []),
  'admin:create': ({ label }) => {
    const name = label.toLowerCase().replace(/[^a-z0-9]+/g, '_');
    admin.gangs.push({ name, label, ranks: structuredClone(gangRanks), members: 0, founderName: null, foundedAt: new Date().toISOString() });
    return ok(admin);
  },
  'admin:save': ({ name, label }) => {
    const target = admin.gangs.find((entry) => entry.name === name);
    if (!target) return fail('That gang no longer exists.');

    target.label = label;
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
    const target = admin.gangs.find((entry) => entry.name === name);
    const rank = target?.ranks.find((entry) => entry.grade === grade);
    const placed = { grade, rank: rank?.name ?? '', isBoss: rank?.isBoss === true };

    if (existing) Object.assign(existing, placed);
    else list.push({ citizenid, name: player?.name ?? citizenid, ...placed, online: true, joinedAt: new Date().toISOString() });

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
