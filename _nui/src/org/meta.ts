import Wrench from 'phosphor-svelte/lib/Wrench';
import ShieldStar from 'phosphor-svelte/lib/ShieldStar';
import FirstAid from 'phosphor-svelte/lib/FirstAid';
import Briefcase from 'phosphor-svelte/lib/Briefcase';
import SquaresFour from 'phosphor-svelte/lib/SquaresFour';
import UsersThree from 'phosphor-svelte/lib/UsersThree';
import Tray from 'phosphor-svelte/lib/Tray';
import Wallet from 'phosphor-svelte/lib/Wallet';
import CarProfile from 'phosphor-svelte/lib/CarProfile';
import Megaphone from 'phosphor-svelte/lib/Megaphone';
import Ranking from 'phosphor-svelte/lib/Ranking';
import GearSix from 'phosphor-svelte/lib/GearSix';
import type { Icon } from '../components/ui/types';
import { t } from '../lib/locale.svelte';
import type { OrgFeature, OrgPage, RankPermission, RequestItem } from '../lib/types';

export function orgIcon(type: string): Icon {
  switch (type) {
    case 'mechanic':
      return Wrench;
    case 'leo':
      return ShieldStar;
    case 'ems':
      return FirstAid;
    default:
      return Briefcase;
  }
}

export function pageLabel(page: OrgPage): string {
  return t(`ui.page.${page}`);
}

export function pageIcon(page: OrgPage, type: string): Icon {
  const icons: Record<Exclude<OrgPage, 'myJob' | 'myJobs'>, Icon> = {
    overview: SquaresFour,
    employees: UsersThree,
    requests: Tray,
    society: Wallet,
    vehicles: CarProfile,
    announcements: Megaphone,
    ranks: Ranking,
    settings: GearSix,
  };

  return page === 'myJob' || page === 'myJobs' ? orgIcon(type) : icons[page];
}

export function permissionText(permission: RankPermission): { title: string; body: string; short: string } {
  return {
    title: t(`ui.rank_permission.${permission}.title`),
    body: t(`ui.rank_permission.${permission}.body`),
    short: t(`ui.rank_permission.${permission}.short`),
  };
}

export const rankPermissions: RankPermission[] = ['open_menu', 'view_dashboard', 'give_bonus', 'society'];

export const features: OrgFeature[] = ['society', 'applications', 'leaves', 'reports', 'vehicles', 'announcements', 'duty', 'secondJobs'];

export function featureText(feature: OrgFeature): { title: string; body: string } {
  return { title: t(`ui.feature.${feature}.title`), body: t(`ui.feature.${feature}.body`) };
}

export function isOpen(request: RequestItem): boolean {
  return request.status === 'open';
}
