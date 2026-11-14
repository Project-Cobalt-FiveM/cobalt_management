import { t } from './locale.svelte';
import type { Iso } from './types';

const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

const weekdays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

const DAY = 86400000;

function pad(value: number): string {
  return value.toString().padStart(2, '0');
}

function monthShort(date: Date): string {
  return t(`ui.date.month_short.${months[date.getMonth()]}`);
}

function monthLong(date: Date): string {
  return t(`ui.date.month.${months[date.getMonth()]}`);
}

export function toDate(value: Iso): Date {
  return new Date(value);
}

export function fromDay(value: string): Date {
  const [year = 0, month = 1, day = 1] = value.split('-').map(Number);
  return new Date(year, month - 1, day);
}

export function toDay(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function money(value: number): string {
  const sign = value < 0 ? '-' : '';
  return `${sign}$${Math.abs(Math.round(value)).toLocaleString('en-US')}`;
}

export function signedMoney(value: number): string {
  return value > 0 ? `+${money(value)}` : money(value);
}

export function hours(minutes: number): string {
  const whole = Math.max(0, Math.floor(minutes));
  return t('ui.time.hours_minutes', Math.floor(whole / 60), pad(whole % 60));
}

export function span(minutes: number): string {
  const whole = Math.max(0, Math.floor(minutes));
  return whole < 60 ? t('ui.time.minutes_short', whole) : hours(whole);
}

export function minutesSince(value: Iso, now: number): number {
  return Math.max(0, Math.floor((now - toDate(value).getTime()) / 60000));
}

export function clock(value: Iso): string {
  const date = toDate(value);
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function dayMonth(date: Date): string {
  return t('ui.date.day_month', date.getDate(), monthShort(date));
}

export function shortDate(value: Iso): string {
  return dayMonth(toDate(value));
}

export function longDate(value: Iso): string {
  const date = toDate(value);
  return t('ui.date.long', date.getDate(), monthShort(date), date.getFullYear());
}

export function longDay(value: string): string {
  const date = fromDay(value);
  return t('ui.date.long', date.getDate(), monthShort(date), date.getFullYear());
}

export function monthYear(value: Iso): string {
  const date = toDate(value);
  return t('ui.date.month_year', monthShort(date), date.getFullYear());
}

export function monthSince(value: Iso, now: number): string {
  const date = toDate(value);
  const month = monthLong(date);
  return date.getFullYear() === new Date(now).getFullYear() ? month : t('ui.date.month_year', month, date.getFullYear());
}

export function weekdayDate(now: number): string {
  const date = new Date(now);
  return t('ui.date.weekday_date', t(`ui.date.weekday.${weekdays[date.getDay()]}`), date.getDate(), monthLong(date));
}

export function daysAgo(value: Iso, now: number): number {
  const start = (time: number) => {
    const date = new Date(time);
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  };

  return Math.round((start(now) - start(toDate(value).getTime())) / DAY);
}

export function stamp(value: Iso, now: number): string {
  const days = daysAgo(value, now);

  if (days === 0) return t('ui.date.today_at', clock(value));
  if (days === 1) return t('ui.date.yesterday');
  return shortDate(value);
}

export function age(value: Iso, now: number): string {
  const minutes = minutesSince(value, now);
  const days = daysAgo(value, now);

  if (minutes < 1) return t('ui.time.now');
  if (minutes < 60) return t('ui.time.minutes_ago_short', minutes);
  if (days === 0) return t('ui.time.hours_ago_short', Math.floor(minutes / 60));
  if (days === 1) return t('ui.date.yesterday');
  return shortDate(value);
}

export function ago(value: Iso, now: number): string {
  const minutes = minutesSince(value, now);
  const days = daysAgo(value, now);

  if (minutes < 1) return t('ui.time.just_now');
  if (minutes < 60) return plural(minutes, 'ui.plural.minutes_ago');
  if (days === 0) return plural(Math.floor(minutes / 60), 'ui.plural.hours_ago');
  if (days === 1) return t('ui.time.yesterday');
  return shortDate(value);
}

export function wait(until: Iso, now: number): string {
  const minutes = Math.max(1, Math.ceil((toDate(until).getTime() - now) / 60000));

  if (minutes < 60) return t('ui.time.minutes_short', minutes);
  if (minutes < 1440) return hours(minutes);
  return t('ui.time.days_hours', Math.floor(minutes / 1440), Math.floor((minutes % 1440) / 60));
}

export function isFuture(value: Iso | null, now: number): value is Iso {
  return value != null && toDate(value).getTime() > now;
}

export function dayRange(from: string, until: string): string {
  const start = fromDay(from);
  const end = fromDay(until);

  if (start.getTime() === end.getTime()) return dayMonth(start);
  if (start.getMonth() === end.getMonth()) return t('ui.date.range', start.getDate(), dayMonth(end));
  return t('ui.date.range', dayMonth(start), dayMonth(end));
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');
}

export function firstName(name: string): string {
  return name.split(/\s+/)[0] ?? name;
}

export function plural(count: number, key: string): string {
  return t(`${key}.${count === 1 ? 'one' : 'other'}`, count);
}

export function list(names: string[]): string {
  if (names.length <= 1) return names[0] ?? '';
  return t('ui.common.list_and', names.slice(0, -1).join(', '), names.at(-1) ?? '');
}
