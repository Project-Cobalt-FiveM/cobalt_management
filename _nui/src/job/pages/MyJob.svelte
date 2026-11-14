<script lang="ts">
  import Lock from 'phosphor-svelte/lib/Lock';
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import Stats from '../../components/ui/Stats.svelte';
  import Stat from '../../components/ui/Stat.svelte';
  import Status from '../../components/ui/Status.svelte';
  import RequestForms from '../RequestForms.svelte';
  import JobsTable from '../JobsTable.svelte';
  import { app } from '../../lib/store.svelte';
  import { isManager, showsJobs } from '../../lib/access';
  import { hours, money, monthSince, shortDate } from '../../lib/format';
  import { ownTitle } from '../requests';
  import { t } from '../../lib/locale.svelte';
  import type { JobSession, RequestItem } from '../../lib/types';

  let { session }: { session: JobSession } = $props();

  const jobs = $derived(showsJobs(session));
  const me = $derived(session.me);
  const boss = $derived(session.bosses[0]);

  function state(request: RequestItem): { tone: 'success' | 'warning' | 'danger'; label: string } {
    if (request.status === 'approved') return { tone: 'success', label: t('ui.common.approved') };
    if (request.status === 'declined') return { tone: 'danger', label: t('ui.common.declined') };
    return { tone: 'warning', label: t('ui.common.waiting') };
  }

  function detail(request: RequestItem): string {
    if (request.status !== 'open' && request.reviewedBy) return t('ui.my_job.answered_by', request.reviewedBy);
    return t('ui.my_job.sent', shortDate(request.createdAt));
  }
</script>

{#if jobs}
  <TopBar title={t('ui.page.myJobs')} subtitle={t('ui.my_job.jobs_subtitle')} />
{:else}
  <TopBar
    title={t('ui.page.myJob')}
    subtitle={me.joinedAt
      ? t('ui.my_job.subtitle_since', me.rank, session.job.label, monthSince(me.joinedAt, app.now))
      : t('ui.my_job.subtitle', me.rank, session.job.label)}
  />
{/if}

<Body>
  <Main>
    {#if jobs}
      <JobsTable {session} />
    {:else}
      <Stats>
        <Stat label={t('ui.common.rank')}>{me.rank}</Stat>
        <Stat label={t('ui.common.pay_per_payday')}>{money(me.pay)}</Stat>
        {#if session.features.duty}<Stat label={t('ui.common.hours_this_week')}>{hours(me.weekMinutes)}</Stat>{/if}
        <Stat label={t('ui.common.bonuses_this_month')}>{money(me.monthBonuses)}</Stat>
      </Stats>
    {/if}

    <RequestForms {session} />
  </Main>

  <Side>
    <section class="flex flex-col gap-3">
      <h2 class="text-base font-semibold">{t('ui.my_job.requests')}</h2>
      {#if session.myRequests.length > 0}
        <div class="flex flex-col rounded-lg border border-border">
          {#each session.myRequests as request (request.id)}
            {@const status = state(request)}
            <div class="flex items-center gap-3 border-b border-border px-3.5 py-3 last:border-b-0">
              <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-semibold">{ownTitle(request)}</span>
                <span class="truncate text-xs text-muted-foreground">{detail(request)}</span>
              </div>
              <Status tone={status.tone} label={status.label} />
            </div>
          {/each}
        </div>
      {:else}
        <p class="text-13 text-muted-foreground">{t('ui.my_job.nothing_sent')}</p>
      {/if}
    </section>

    {#if !isManager(session)}
      <div class="flex gap-3 rounded-lg border border-border bg-muted p-4">
        <Lock size="1rem" class="mt-0.5 shrink-0 text-muted-foreground" />
        <div class="flex flex-col gap-1">
          <span class="text-sm font-semibold">{t('ui.my_job.locked')}</span>
          <p class="text-13 text-muted-foreground">
            {t('ui.my_job.locked_body')}
            {#if boss}{t('ui.my_job.locked_boss', boss)}{/if}
          </p>
        </div>
      </div>
    {/if}
  </Side>
</Body>
