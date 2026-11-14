export type Iso = string;

export type JobFeature =
  | 'society'
  | 'applications'
  | 'leaves'
  | 'reports'
  | 'vehicles'
  | 'announcements'
  | 'duty'
  | 'secondJobs';

export type RankPermission = 'open_menu' | 'view_dashboard' | 'give_bonus' | 'society';

export type JobPage =
  | 'overview'
  | 'employees'
  | 'requests'
  | 'society'
  | 'vehicles'
  | 'announcements'
  | 'ranks'
  | 'settings'
  | 'myJob'
  | 'myJobs';

export interface JobInfo {
  name: string;
  label: string;
  type: string;
  typeLabel: string;
  logoUrl: string | null;
}

export interface Rank {
  grade: number;
  name: string;
  pay: number;
  isBoss: boolean;
  people: number;
  permissions: RankPermission[];
}

export interface Employee {
  citizenid: string;
  name: string;
  grade: number;
  rank: string;
  pay: number;
  isBoss: boolean;
  online: boolean;
  onDuty: boolean;
  onLeave: boolean;
  joinedAt: Iso | null;
  shiftStartedAt: Iso | null;
  weekMinutes: number;
  lastWeekMinutes: number;
  monthBonuses: number;
  secondJob?: boolean;
}

export interface Me {
  citizenid: string;
  name: string;
  grade: number;
  rank: string;
  pay: number;
  isBoss: boolean;
  onDuty: boolean;
  shiftStartedAt: Iso | null;
  joinedAt: Iso | null;
  weekMinutes: number;
  monthBonuses: number;
}

export interface Access {
  overview: boolean;
  employees: boolean;
  bonus: boolean;
  manageStaff: boolean;
  requests: boolean;
  society: boolean;
  vehicles: boolean;
  announce: boolean;
  ranks: boolean;
  settings: boolean;
}

export type RequestKind = 'application' | 'leave' | 'report';

export type RequestStatus = 'open' | 'approved' | 'declined';

export interface Applicant {
  phone: string | null;
  currentJob: string | null;
  workedHereBefore: boolean;
  online: boolean;
}

export interface RequestItem {
  id: number;
  kind: RequestKind;
  status: RequestStatus;
  citizenid: string;
  name: string;
  title: string;
  message: string;
  startDate: string | null;
  endDate: string | null;
  createdAt: Iso;
  reviewedBy: string | null;
  reviewedAt: Iso | null;
  applicant: Applicant | null;
}

export interface Transaction {
  id: number;
  at: Iso;
  description: string;
  by: string;
  amount: number;
}

export interface Society {
  accountId: string;
  balance: number;
  payroll: number;
  nextPaydayAt: Iso;
  transactions: Transaction[];
}

export interface CatalogueVehicle {
  model: string;
  label: string;
  use: string;
  minGrade: number;
  minRank: string;
  price: number;
}

export interface FleetVehicle {
  plate: string;
  model: string;
  label: string;
  boughtBy: string;
  boughtAt: Iso;
}

export interface Vehicles {
  catalogue: CatalogueVehicle[];
  fleet: FleetVehicle[];
}

export interface Announcement {
  id: number;
  title: string;
  message: string;
  author: string;
  createdAt: Iso;
}

export interface Stats {
  total: number;
  onDuty: number;
  weekMinutes: number;
  weekBonuses: number;
  fleet: number;
}

export interface JobEntry {
  name: string;
  label: string;
  rank: string;
  pay: number;
  since: Iso | null;
  isMain: boolean;
  onDuty: boolean;
}

export interface JobSession {
  mode: 'job';
  now: Iso;
  job: JobInfo;
  me: Me;
  access: Access;
  features: Record<JobFeature, boolean>;
  bosses: string[];
  ranks: Rank[];
  stats: Stats | null;
  employees: Employee[] | null;
  requests: RequestItem[] | null;
  society: Society | null;
  vehicles: Vehicles | null;
  announcements: Announcement[];
  myRequests: RequestItem[];
  myJobs: JobEntry[];
  hireRadius: number;
  logoHosts: string[];
  limits: { bonus: number; message: number; title: number; reason: number };
}

export interface NearbyPlayer {
  serverId: number;
  citizenid: string;
  name: string;
  distance: number;
  job: string | null;
  appliedAt: Iso | null;
}

export type GangPermission = 'vault_view' | 'vault_deposit' | 'vault_withdraw' | 'vault_audit' | 'gang_invite';

export interface GangPermissionDef {
  id: GangPermission;
  label: string;
}

export interface GangRank {
  grade: number;
  name: string;
  isBoss: boolean;
}

export interface GangMember {
  citizenid: string;
  name: string;
  grade: number;
  rank: string;
  isBoss: boolean;
  online: boolean;
  joinedAt: Iso | null;
}

export interface VaultEntry {
  id: number;
  at: Iso;
  what: string;
  who: string;
  amount: number;
}

export interface GangSession {
  mode: 'gang';
  now: Iso;
  gang: {
    name: string;
    label: string;
    foundedAt: Iso;
  };
  me: {
    citizenid: string;
    name: string;
    grade: number;
    rank: string;
    isBoss: boolean;
    isFounder: boolean;
    permissions: GangPermission[];
  };
  ranks: GangRank[];
  members: GangMember[];
  inviteRadius: number;
  permissionCatalog: GangPermissionDef[];
  permissions: Record<string, GangPermission[]>;
  vault: {
    balance: number;
    canSee: boolean;
    canDeposit: boolean;
    canWithdraw: boolean;
    canSeeHistory: boolean;
    history: VaultEntry[];
  };
}

export interface GangNearby {
  serverId: number;
  name: string;
  distance: number;
  gangLabel?: string | null;
}

export interface AdminGang {
  name: string;
  label: string;
  ranks: GangRank[];
  members: number;
  founderName: string | null;
  foundedAt: Iso;
}

export interface OnlinePlayer {
  serverId: number;
  citizenid: string;
  name: string;
  gangLabel?: string | null;
}

export interface AdminSession {
  mode: 'gangAdmin';
  now: Iso;
  admin: { name: string; rank: string };
  gangs: AdminGang[];
  maxGangs: number;
  nameLength: { min: number; max: number };
  onlinePlayers: OnlinePlayer[];
}

export interface ApplySession {
  mode: 'apply';
  now: Iso;
  job: JobInfo;
  reviewers: string[];
  startingRank: string;
  startingPay: number;
  staff: number;
  maxLength: number;
  pending: RequestItem | null;
}

export interface CharterSession {
  mode: 'charter';
  now: Iso;
  price: number;
  carried: number;
  slotsUsed: number;
  maxSlots: number;
  bossRank: string;
  nameLength: { min: number; max: number };
}

export type Session = JobSession | GangSession | AdminSession | ApplySession | CharterSession;

export type Result<S> = { ok: true; session: S } | { ok: false; error: string };

type JobResult = Result<JobSession>;
type GangResult = Result<GangSession>;
type AdminResult = Result<AdminSession>;

export interface Requests {
  close: [void, { ok: true }];
  setDuty: [{ onDuty: boolean }, JobResult];
  nearbyPlayers: [void, NearbyPlayer[]];
  hire: [{ citizenid: string; grade: number; asSecondJob: boolean }, JobResult];
  fire: [{ citizenid: string; reason: string }, JobResult];
  setGrade: [{ citizenid: string; grade: number }, JobResult];
  giveBonus: [{ citizenid: string; amount: number; reason: string }, JobResult];
  answerRequest: [{ id: number; approve: boolean; grade?: number }, JobResult];
  deposit: [{ amount: number; note: string }, JobResult];
  withdraw: [{ amount: number; note: string }, JobResult];
  saveRank: [{ grade: number; pay: number; permissions: RankPermission[] }, JobResult];
  buyVehicle: [{ model: string }, JobResult];
  postAnnouncement: [{ title: string; message: string }, JobResult];
  saveLogo: [{ url: string }, JobResult];
  setFeature: [{ feature: JobFeature; enabled: boolean }, JobResult];
  sendLeave: [{ from: string; until: string; reason: string }, JobResult];
  sendReport: [{ title: string; message: string }, JobResult];
  makeMainJob: [{ name: string }, JobResult];
  leaveJob: [{ name: string }, JobResult];

  'gang:nearby': [void, GangNearby[]];
  'gang:invite': [{ serverId: number }, GangResult];
  'gang:kick': [{ citizenid: string }, GangResult];
  'gang:passLeadership': [{ citizenid: string }, GangResult];
  'gang:leave': [void, { ok: boolean; error?: string }];
  'gang:disband': [void, { ok: boolean; error?: string }];
  'gang:savePermissions': [{ permissions: Record<string, GangPermission[]> }, GangResult];
  'gang:resetPermissions': [void, GangResult];
  'gang:withdraw': [{ amount: number }, GangResult];

  'admin:members': [{ name: string }, GangMember[]];
  'admin:create': [{ label: string }, AdminResult];
  'admin:save': [{ name: string; label: string }, AdminResult];
  'admin:delete': [{ name: string }, AdminResult];
  'admin:assign': [{ name: string; citizenid: string; grade: number }, AdminResult];
  'admin:remove': [{ name: string; citizenid: string }, AdminResult];

  'apply:send': [{ job: string; message: string }, Result<ApplySession>];
  'charter:send': [{ label: string }, { ok: boolean; error?: string }];
}

export type Messages =
  | { action: 'open'; data: Session; locales?: Record<string, string> }
  | { action: 'close' }
  | { action: 'update'; data: Session };
