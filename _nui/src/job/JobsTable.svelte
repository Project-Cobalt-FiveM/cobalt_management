<script lang="ts">
  import Badge from '../components/ui/Badge.svelte';
  import Button from '../components/ui/Button.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Status from '../components/ui/Status.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { longDate, money } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { JobEntry, JobSession } from '../lib/types';

  let { session }: { session: JobSession } = $props();

  const change = new Action();
  const leave = new Action();

  let leaving = $state<JobEntry | null>(null);

  const jobs = $derived([...session.myJobs].sort((a, b) => Number(b.isMain) - Number(a.isMain)));

  function since(job: JobEntry): string {
    if (!job.since) return job.isMain ? t('ui.jobs.main') : t('ui.jobs.second');
    return job.isMain ? t('ui.jobs.since', longDate(job.since)) : t('ui.jobs.second_since', longDate(job.since));
  }

  async function confirmLeave() {
    if (!leaving) return;

    const name = leaving.name;
    if (await leave.run(() => fetchNui('leaveJob', { name }))) leaving = null;
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex flex-col overflow-clip rounded-lg border border-border">
    <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
      <span class="flex-1">{t('ui.jobs.job')}</span>
      <span class="w-40 shrink-0">{t('ui.common.rank')}</span>
      <span class="w-20 shrink-0 text-right">{t('ui.common.pay')}</span>
      <span class="w-28 shrink-0 pl-6">{t('ui.common.status')}</span>
      <span class="w-48 shrink-0"></span>
    </div>
    {#each jobs as job (job.name)}
      <div class="flex min-h-16 items-center gap-4 border-b border-border px-4 py-3 last:border-b-0">
        <span class="flex min-w-0 flex-1 flex-col gap-0.5">
          <span class="flex items-center gap-2">
            <span class="truncate text-sm font-semibold">{job.label}</span>
            {#if job.isMain}<Badge tone="primary">{t('ui.jobs.main')}</Badge>{/if}
          </span>
          <span class="truncate text-xs text-muted-foreground">{since(job)}</span>
        </span>
        <span class="w-40 shrink-0 truncate text-13 font-medium">{job.rank}</span>
        <span class="w-20 shrink-0 text-right text-sm font-semibold tabular-nums">{money(job.pay)}</span>
        <span class="w-28 shrink-0 pl-6"><Status tone={job.onDuty ? 'success' : 'muted'} label={job.onDuty ? t('ui.common.on_duty') : t('ui.common.off_duty')} /></span>
        <span class="flex w-48 shrink-0 justify-end gap-1.5">
          {#if !job.isMain}
            <Button size="xs" disabled={change.busy} onclick={() => change.run(() => fetchNui('makeMainJob', { name: job.name }))}>{t('ui.jobs.make_main')}</Button>
            <Button size="xs" onclick={() => (leaving = job)}>{t('ui.jobs.leave')}</Button>
          {/if}
        </span>
      </div>
    {/each}
  </div>
  <ErrorText error={change.error} />
  <p class="text-xs text-muted-foreground">{t('ui.jobs.note')}</p>
</div>

{#if leaving}
  <Dialog
    title={t('ui.jobs.leave_title', leaving.label)}
    description={t('ui.jobs.leave_body', leaving.rank.toLowerCase())}
    onclose={() => (leaving = null)}
  >
    <ErrorText error={leave.error} />
    {#snippet actions()}
      <Button onclick={() => (leaving = null)}>{t('ui.common.cancel')}</Button>
      <Button variant="destructive" disabled={leave.busy} onclick={confirmLeave}>{t('ui.jobs.leave_job', leaving?.label ?? '')}</Button>
    {/snippet}
  </Dialog>
{/if}
