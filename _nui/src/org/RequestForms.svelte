<script lang="ts">
  import CalendarBlank from 'phosphor-svelte/lib/CalendarBlank';
  import Segmented from '../components/ui/Segmented.svelte';
  import Select from '../components/ui/Select.svelte';
  import Button from '../components/ui/Button.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { fromDay, list, longDay, toDay } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { OrgSession } from '../lib/types';
  import type { Option, Tab } from '../components/ui/types';

  type Form = 'leave' | 'report';

  let { session }: { session: OrgSession } = $props();

  const send = new Action();

  const forms = $derived<Tab<Form>[]>([
    ...(session.features.leaves ? [{ value: 'leave' as const, label: t('ui.forms.request_leave') }] : []),
    ...(session.features.reports ? [{ value: 'report' as const, label: t('ui.forms.report_problem') }] : []),
  ]);

  let form = $state<Form>('leave');
  let from = $state<string | null>(null);
  let until = $state<string | null>(null);
  let reason = $state('');
  let title = $state('');
  let message = $state('');
  let sentNote = $state<string | null>(null);

  $effect(() => {
    if (!forms.some((entry) => entry.value === form) && forms[0]) form = forms[0].value;
  });

  const days = $derived.by(() => {
    const today = new Date(app.now);
    return Array.from({ length: 60 }, (_, index) => new Date(today.getFullYear(), today.getMonth(), today.getDate() + index));
  });

  function label(date: Date): string {
    return longDay(toDay(date));
  }

  const fromOptions = $derived<Option<string>[]>(days.map((date) => ({ value: toDay(date), label: label(date) })));
  const untilOptions = $derived<Option<string>[]>(
    days.filter((date) => !from || date.getTime() >= fromDay(from).getTime()).map((date) => ({ value: toDay(date), label: label(date) })),
  );

  const recipients = $derived(session.bosses.length > 0 ? t('ui.forms.goes_to', list(session.bosses)) : t('ui.forms.goes_to_managers'));
  const leaveValid = $derived(from !== null && until !== null && fromDay(until).getTime() >= fromDay(from).getTime());
  const reportValid = $derived(title.trim().length > 0 && message.trim().length > 0);

  function pickFrom(value: string) {
    if (until && fromDay(until).getTime() < fromDay(value).getTime()) until = value;
    send.clear();
  }

  async function sendLeave() {
    if (!from || !until) return;

    const payload = { from, until, reason: reason.trim() };
    if (await send.run(() => fetchNui('sendLeave', payload))) {
      from = null;
      until = null;
      reason = '';
      sentNote = t('ui.forms.leave_sent');
    }
  }

  async function sendReport() {
    const payload = { title: title.trim(), message: message.trim() };
    if (await send.run(() => fetchNui('sendReport', payload))) {
      title = '';
      message = '';
      sentNote = t('ui.forms.report_sent');
    }
  }

  function switchTo() {
    send.clear();
    sentNote = null;
  }
</script>

{#if forms.length > 0}
  <div class="flex max-w-140 flex-col gap-4">
    <Segmented tabs={forms} bind:value={form} onchange={switchTo} />

    {#if form === 'leave'}
      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-2">
          <span class="text-sm font-semibold">{t('ui.common.from')}</span>
          <Select label={t('ui.common.from')} icon={CalendarBlank} placeholder={t('ui.common.pick_day')} options={fromOptions} bind:value={from} onchange={pickFrom} />
        </div>
        <div class="flex flex-col gap-2">
          <span class="text-sm font-semibold">{t('ui.common.until')}</span>
          <Select
            label={t('ui.common.until')}
            icon={CalendarBlank}
            placeholder={t('ui.common.pick_day')}
            options={untilOptions}
            bind:value={until}
            onchange={() => send.clear()}
          />
        </div>
      </div>
      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.common.reason')}</span>
        <textarea class="field h-22 resize-none py-2.5" placeholder={t('ui.forms.reason_placeholder')} maxlength={session.limits.reason} bind:value={reason}></textarea>
      </label>
      <div class="flex items-center gap-3">
        <Button variant="primary" disabled={!leaveValid || send.busy} onclick={sendLeave}>{t('ui.forms.send_leave')}</Button>
        <span class="text-xs text-muted-foreground">{sentNote ?? recipients}</span>
      </div>
    {:else}
      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.forms.whats_wrong')}</span>
        <input class="field" placeholder={t('ui.forms.title_placeholder')} maxlength={session.limits.title} bind:value={title} />
      </label>
      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.forms.details')}</span>
        <textarea class="field h-28 resize-none py-2.5" placeholder={t('ui.forms.details_placeholder')} maxlength={session.limits.message} bind:value={message}></textarea>
      </label>
      <div class="flex items-center gap-3">
        <Button variant="primary" disabled={!reportValid || send.busy} onclick={sendReport}>{t('ui.forms.send_report')}</Button>
        <span class="text-xs text-muted-foreground">{sentNote ?? recipients}</span>
      </div>
    {/if}
    <ErrorText error={send.error} />
  </div>
{/if}
