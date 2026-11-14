import UserPlus from 'phosphor-svelte/lib/UserPlus';
import CalendarBlank from 'phosphor-svelte/lib/CalendarBlank';
import Flag from 'phosphor-svelte/lib/Flag';
import type { Icon } from '../components/ui/types';
import { ago, dayRange } from '../lib/format';
import { t } from '../lib/locale.svelte';
import type { RequestItem, RequestKind } from '../lib/types';

export const kindIcons: Record<RequestKind, Icon> = { application: UserPlus, leave: CalendarBlank, report: Flag };

export function range(request: RequestItem): string {
  return request.startDate && request.endDate ? dayRange(request.startDate, request.endDate) : '';
}

export function headline(request: RequestItem): string {
  switch (request.kind) {
    case 'application':
      return t('ui.request.wants_to_join', request.name);
    case 'leave':
      return t('ui.request.leave_headline', request.name, range(request));
    case 'report':
      return request.title;
  }
}

export function summary(request: RequestItem, now: number): string {
  switch (request.kind) {
    case 'application':
      return t('ui.request.application_summary', ago(request.createdAt, now));
    case 'leave':
      return request.message ? t('ui.request.leave_summary_reason', request.message) : t('ui.request.leave_summary');
    case 'report':
      return t('ui.request.report_from', request.name);
  }
}

export function preview(request: RequestItem): string {
  switch (request.kind) {
    case 'application':
      return t('ui.request.application_preview', request.message);
    case 'leave':
      return t('ui.request.leave_preview', range(request), request.message);
    case 'report':
      return t('ui.request.report_preview', request.title);
  }
}

export function ownTitle(request: RequestItem): string {
  return request.kind === 'leave' ? t('ui.request.leave_title', range(request)) : request.title;
}
