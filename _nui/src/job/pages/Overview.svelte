<script lang="ts">
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import Button from '../../components/ui/Button.svelte';
  import Section from '../../components/ui/Section.svelte';
  import LinkButton from '../../components/ui/LinkButton.svelte';
  import Stats from '../../components/ui/Stats.svelte';
  import Stat from '../../components/ui/Stat.svelte';
  import Emphasis from '../../components/ui/Emphasis.svelte';
  import { app, type FundsMode } from '../../lib/store.svelte';
  import { canOpen } from '../../lib/access';
  import { hours, longDate, minutesSince, money, plural, shortDate, span, weekdayDate } from '../../lib/format';
  import { parts, t } from '../../lib/locale.svelte';
  import { isOpen } from '../meta';
  import { headline, kindIcons, summary } from '../requests';
  import type { JobSession } from '../../lib/types';

  let { session }: { session: JobSession } = $props();

  const duty = $derived(session.features.duty);
  const stats = $derived(session.stats);
  const employees = $derived(session.employees ?? []);
  const shown = $derived(duty ? employees.filter((employee) => employee.onDuty) : employees);
  const waiting = $derived((session.requests ?? []).filter(isOpen).slice(0, 4));
  const latest = $derived(session.announcements[0]);
  const society = $derived(session.society && canOpen(session, 'society') ? session.society : null);
  const paydaysLeft = $derived(society && society.payroll > 0 ? Math.floor(society.balance / society.payroll) : null);
  const headcount = $derived(stats ? (duty ? t('ui.overview.on_duty_count', stats.onDuty, stats.total) : plural(stats.total, 'ui.plural.person')) : null);
  const payroll = $derived(
    society && paydaysLeft !== null
      ? parts('ui.overview.payroll_left', money(society.payroll), paydaysLeft)
      : parts('ui.overview.payroll', money(society?.payroll ?? 0)),
  );

  function openFunds(mode: FundsMode) {
    app.fundsMode = mode;
    app.goJob('society');
  }
</script>

<TopBar title={t('ui.page.overview')} subtitle={headcount ? t('ui.overview.subtitle', weekdayDate(app.now), headcount) : weekdayDate(app.now)} />

<Body>
  <Main>
    {#if society}
      <div class="flex items-end gap-6">
        <div class="flex flex-1 flex-col gap-1.5">
          <span class="text-13 font-medium text-muted-foreground">{t('ui.overview.society_account')}</span>
          <span class="text-[2.75rem] leading-12 font-semibold tracking-[-0.02em] tabular-nums">{money(society.balance)}</span>
          <p class="text-sm text-muted-foreground"><Emphasis parts={payroll} /></p>
        </div>
        <div class="flex shrink-0 gap-2">
          <Button onclick={() => openFunds('withdraw')}>{t('ui.common.withdraw')}</Button>
          <Button variant="primary" onclick={() => openFunds('deposit')}>{t('ui.common.deposit')}</Button>
        </div>
      </div>
    {/if}

    {#if stats}
      <Stats>
        {#if duty}
          <Stat label={t('ui.overview.on_duty_now')}>{stats.onDuty} <span class="text-sm font-normal text-muted-foreground">{t('ui.overview.of_total', stats.total)}</span></Stat>
          <Stat label={t('ui.common.hours_this_week')}>{hours(stats.weekMinutes)}</Stat>
        {:else}
          <Stat label={t('ui.page.employees')}>{stats.total}</Stat>
        {/if}
        <Stat label={t('ui.overview.bonuses_week')}>{money(stats.weekBonuses)}</Stat>
        {#if session.features.vehicles}
          <Stat label={t('ui.overview.fleet')}>{plural(stats.fleet, 'ui.plural.vehicle')}</Stat>
        {/if}
      </Stats>
    {/if}

    {#if session.employees}
      <Section title={duty ? t('ui.overview.on_duty_now') : t('ui.page.employees')}>
        {#snippet aside()}
          {#if canOpen(session, 'employees')}<LinkButton onclick={() => app.goJob('employees')}>{t('ui.overview.all_employees')}</LinkButton>{/if}
        {/snippet}
        <div class="flex flex-col overflow-clip rounded-lg border border-border">
          <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
            <span class="flex-1">{t('ui.common.employee')}</span>
            <span class="w-35 shrink-0">{t('ui.common.rank')}</span>
            <span class="w-30 shrink-0">{duty ? t('ui.overview.on_shift_for') : t('ui.common.joined')}</span>
            <span class="w-25 shrink-0 text-right">{duty ? t('ui.common.this_week') : t('ui.common.pay')}</span>
          </div>
          {#each shown as employee (employee.citizenid)}
            <div class="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0">
              <span class="flex-1 truncate text-sm font-medium">{employee.name}</span>
              <span class="w-35 shrink-0 truncate text-13">{employee.rank}</span>
              {#if duty}
                <span class="w-30 shrink-0 text-13 text-muted-foreground tabular-nums">{employee.shiftStartedAt ? span(minutesSince(employee.shiftStartedAt, app.now)) : ''}</span>
                <span class="w-25 shrink-0 text-right text-13 tabular-nums">{hours(employee.weekMinutes)}</span>
              {:else}
                <span class="w-30 shrink-0 text-13 text-muted-foreground tabular-nums">{employee.joinedAt ? longDate(employee.joinedAt) : ''}</span>
                <span class="w-25 shrink-0 text-right text-13 tabular-nums">{money(employee.pay)}</span>
              {/if}
            </div>
          {:else}
            <p class="px-4 py-6 text-center text-13 text-muted-foreground">{t('ui.overview.nobody_on_duty')}</p>
          {/each}
        </div>
      </Section>
    {/if}
  </Main>

  {#if canOpen(session, 'requests') || session.features.announcements}
    <Side>
      {#if canOpen(session, 'requests')}
        <Section title={t('ui.overview.waiting')}>
          {#snippet aside()}<LinkButton onclick={() => app.goJob('requests')}>{t('ui.page.requests')}</LinkButton>{/snippet}
          {#if waiting.length > 0}
            <div class="flex flex-col rounded-lg border border-border">
              {#each waiting as request (request.id)}
                {@const Glyph = kindIcons[request.kind]}
                <button
                  type="button"
                  class="flex items-center gap-3 border-b border-border px-3.5 py-3 text-left transition-colors last:border-b-0 hover:bg-muted"
                  onclick={() => app.goJob('requests')}
                >
                  <Glyph size="1rem" class="shrink-0 text-muted-foreground" />
                  <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span class="truncate text-sm font-medium">{headline(request)}</span>
                    <span class="truncate text-xs text-muted-foreground">{summary(request, app.now)}</span>
                  </span>
                </button>
              {/each}
            </div>
          {:else}
            <p class="text-13 text-muted-foreground">{t('ui.overview.nothing_waiting')}</p>
          {/if}
        </Section>
      {/if}

      {#if session.features.announcements}
        <Section title={t('ui.overview.latest')}>
          {#snippet aside()}<LinkButton onclick={() => app.goJob('announcements')}>{t('ui.common.all')}</LinkButton>{/snippet}
          {#if latest}
            <div class="flex flex-col gap-1.5">
              <span class="text-sm font-medium">{latest.title}</span>
              <p class="text-sm text-muted-foreground">{latest.message}</p>
              <span class="text-xs text-muted-foreground">{t('ui.common.by_on', latest.author, shortDate(latest.createdAt))}</span>
            </div>
          {:else}
            <p class="text-13 text-muted-foreground">{t('ui.common.no_announcements')}</p>
          {/if}
        </Section>
      {/if}
    </Side>
  {/if}
</Body>
