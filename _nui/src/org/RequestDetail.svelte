<script lang="ts">
  import Avatar from '../components/ui/Avatar.svelte';
  import Button from '../components/ui/Button.svelte';
  import Select from '../components/ui/Select.svelte';
  import Stats from '../components/ui/Stats.svelte';
  import Stat from '../components/ui/Stat.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { clock, daysAgo, firstName, fromDay, longDay, money, plural, shortDate } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { OrgSession, RequestItem } from '../lib/types';

  let { session, request }: { session: OrgSession; request: RequestItem } = $props();

  const answer = new Action();

  const ranks = $derived([...session.ranks].filter((rank) => session.me.isBoss || rank.grade < session.me.grade).sort((a, b) => a.grade - b.grade));
  const options = $derived(ranks.map((rank) => ({ value: rank.grade, label: t('ui.request.hire_option', rank.name, money(rank.pay)) })));

  let grade = $state<number | null>(null);

  $effect(() => {
    if (grade === null) grade = ranks[0]?.grade ?? null;
  });

  const first = $derived(firstName(request.name));
  const hireRank = $derived(ranks.find((rank) => rank.grade === grade));
  const open = $derived(request.status === 'open');

  const sent = $derived.by(() => {
    const days = daysAgo(request.createdAt, app.now);

    if (days === 0) return t('ui.request.sent_today', clock(request.createdAt));
    if (days === 1) return t('ui.request.sent_yesterday', clock(request.createdAt));
    return t('ui.request.sent_on', shortDate(request.createdAt));
  });

  const title = $derived.by(() => {
    switch (request.kind) {
      case 'application':
        return t('ui.request.wants_to_join', request.name);
      case 'leave':
        return t('ui.request.wants_time_off', request.name);
      case 'report':
        return request.title;
    }
  });

  const subtitle = $derived.by(() => {
    switch (request.kind) {
      case 'application':
        return [
          t('ui.request.application_sent', sent),
          t('ui.request.citizen_id', request.citizenid),
          request.applicant?.phone ? t('ui.request.phone', request.applicant.phone) : null,
        ]
          .filter(Boolean)
          .join(', ');
      case 'leave':
        return t('ui.request.leave_sent', sent, request.citizenid);
      case 'report':
        return t('ui.request.report_sent', request.name, sent);
    }
  });

  const days = $derived(
    request.startDate && request.endDate ? Math.round((fromDay(request.endDate).getTime() - fromDay(request.startDate).getTime()) / 86400000) + 1 : 0,
  );

  const footnote = $derived.by(() => {
    switch (request.kind) {
      case 'application':
        return t('ui.request.footnote_application');
      case 'leave':
        return t('ui.request.footnote_leave');
      case 'report':
        return t('ui.request.footnote_report');
    }
  });

  const labels = $derived.by(() => {
    switch (request.kind) {
      case 'application':
        return {
          decline: t('ui.request.decline'),
          approve: hireRank ? t('ui.request.hire_as', first, hireRank.name.toLowerCase()) : t('ui.request.hire', first),
        };
      case 'leave':
        return { decline: t('ui.request.decline'), approve: t('ui.request.approve_leave') };
      case 'report':
        return { decline: t('ui.request.dismiss'), approve: t('ui.request.mark_handled') };
    }
  });

  const verdict = $derived.by(() => {
    const status = request.status === 'approved' ? t('ui.common.approved') : t('ui.common.declined');
    const by = request.reviewedBy ? t('ui.request.reviewed_by', status, request.reviewedBy) : status;
    return request.reviewedAt ? t('ui.request.reviewed_on', by, shortDate(request.reviewedAt)) : by;
  });

  function reply(approve: boolean) {
    const hireGrade = approve && request.kind === 'application' ? grade : null;
    const payload = hireGrade === null ? { id: request.id, approve } : { id: request.id, approve, grade: hireGrade };

    void answer.run(() => fetchNui('answerRequest', payload));
  }
</script>

<div class="flex min-w-0 flex-1 flex-col px-8 pt-7 pb-6">
  <div class="flex items-center gap-4">
    <Avatar name={request.name} size="lg" />
    <div class="flex min-w-0 flex-col gap-0.5">
      <h2 class="truncate text-[1.375rem] leading-8 font-semibold tracking-[-0.01em]">{title}</h2>
      <p class="truncate text-13 text-muted-foreground tabular-nums">{subtitle}</p>
    </div>
  </div>

  <div class="mt-8 flex max-w-160 flex-col gap-2">
    <span class="text-sm font-semibold">{request.kind === 'report' ? t('ui.request.what_happened') : t('ui.common.message')}</span>
    <p class="text-15 leading-6 whitespace-pre-line">{request.message || t('ui.request.no_message')}</p>
  </div>

  {#if request.kind === 'application' && request.applicant}
    <div class="mt-6 max-w-160">
      <Stats>
        <Stat label={t('ui.request.current_job')} size="md">{request.applicant.currentJob ?? t('ui.common.unemployed')}</Stat>
        <Stat label={t('ui.request.worked_before')} size="md">{request.applicant.workedHereBefore ? t('ui.common.yes') : t('ui.common.no')}</Stat>
        <Stat label={t('ui.common.in_the_city')} size="md">{request.applicant.online ? t('ui.request.online_now') : t('ui.common.away')}</Stat>
      </Stats>
    </div>
  {:else if request.kind === 'leave' && request.startDate && request.endDate}
    <div class="mt-6 max-w-160">
      <Stats>
        <Stat label={t('ui.common.from')} size="md">{longDay(request.startDate)}</Stat>
        <Stat label={t('ui.common.until')} size="md">{longDay(request.endDate)}</Stat>
        <Stat label={t('ui.request.length')} size="md">{plural(days, 'ui.plural.day')}</Stat>
      </Stats>
    </div>
  {/if}

  {#if open && request.kind === 'application' && session.access.manageStaff}
    <div class="mt-8 flex w-75 flex-col gap-2">
      <span class="text-sm font-semibold">{t('ui.request.hire_as_label')}</span>
      <Select label={t('ui.request.hire_as_label')} {options} bind:value={grade} />
    </div>
  {/if}

  <div class="mt-auto flex items-center gap-4 border-t border-border pt-4">
    <div class="flex min-w-0 flex-1 flex-col gap-1">
      {#if open}
        <p class="text-xs text-muted-foreground">{footnote}</p>
      {:else}
        <p class="text-13 text-muted-foreground">{verdict}</p>
      {/if}
      <ErrorText error={answer.error} />
    </div>
    {#if open && session.access.requests}
      <Button disabled={answer.busy} onclick={() => reply(false)}>{labels.decline}</Button>
      <Button variant="primary" disabled={answer.busy} onclick={() => reply(true)}>{labels.approve}</Button>
    {/if}
  </div>
</div>
