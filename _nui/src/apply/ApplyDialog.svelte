<script lang="ts">
  import Mark from '../components/shell/Mark.svelte';
  import CloseHint from '../components/shell/CloseHint.svelte';
  import Button from '../components/ui/Button.svelte';
  import Stats from '../components/ui/Stats.svelte';
  import Stat from '../components/ui/Stat.svelte';
  import TextArea from '../components/ui/TextArea.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { list, money, plural, shortDate } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { rise } from '../lib/motion';
  import { orgIcon } from '../org/meta';
  import type { ApplySession } from '../lib/types';

  let { session }: { session: ApplySession } = $props();

  const send = new Action();

  let message = $state('');

  const reviewers = $derived(session.reviewers.length > 0 ? list(session.reviewers) : t('ui.common.the_managers'));
  const valid = $derived(message.trim().length > 0);

  function submit() {
    if (!valid) return;

    const payload = { org: session.org.name, message: message.trim() };
    void send.run(() => fetchNui('apply:send', payload));
  }
</script>

<div class="fixed inset-0 flex items-center justify-center">
  <div class="flex w-190 flex-col overflow-hidden rounded-lg border border-border bg-card shadow-lg" role="dialog" aria-modal="true" aria-label={t('ui.apply.aria', session.org.label)} transition:rise={{ duration: 300 }}>
    <header class="flex h-18 shrink-0 items-center gap-3 border-b border-border px-6">
      <Mark icon={orgIcon(session.org.type)} logo={session.org.logoUrl} />
      <div class="flex min-w-0 flex-1 flex-col gap-0.5">
        <span class="truncate text-15 font-semibold">{session.org.label}</span>
        <span class="truncate text-xs text-muted-foreground">{session.org.typeLabel}</span>
      </div>
      <CloseHint />
    </header>

    <div class="flex flex-col gap-6 px-8 pt-8 pb-7">
      {#if session.pending}
        <div class="flex flex-col gap-2">
          <h2 class="text-2xl font-semibold tracking-tight">{t('ui.apply.pending_title')}</h2>
          <p class="text-sm text-muted-foreground">{t('ui.apply.pending_body', shortDate(session.pending.createdAt), reviewers)}</p>
        </div>
        <div class="flex flex-col gap-2 rounded-lg border border-border bg-muted p-4">
          <span class="text-sm font-semibold">{t('ui.apply.what_you_wrote')}</span>
          <p class="text-sm whitespace-pre-line text-muted-foreground">{session.pending.message}</p>
        </div>
        <div class="flex justify-end">
          <Button onclick={() => app.close()}>{t('ui.common.close')}</Button>
        </div>
      {:else}
        <div class="flex flex-col gap-2">
          <h2 class="text-2xl font-semibold tracking-tight">{t('ui.apply.title')}</h2>
          <p class="text-sm text-muted-foreground">{t('ui.apply.intro', reviewers)}</p>
        </div>

        <Stats>
          <Stat label={t('ui.apply.starting_rank')} size="md">{session.startingRank}</Stat>
          <Stat label={t('ui.apply.starting_pay')} size="md">{t('ui.common.per_payday', money(session.startingPay))}</Stat>
          <Stat label={t('ui.apply.staff')} size="md">{plural(session.staff, 'ui.plural.person')}</Stat>
        </Stats>

        <div class="flex flex-col gap-2">
          <span class="text-sm font-semibold">{t('ui.apply.why')}</span>
          <TextArea
            label={t('ui.apply.why')}
            placeholder={t('ui.apply.why_placeholder')}
            max={session.maxLength}
            rows="h-35"
            hint={t('ui.apply.name_note')}
            focus
            bind:value={message}
          />
        </div>

        <div class="flex items-center gap-2">
          <div class="flex min-w-0 flex-1 flex-col gap-1">
            <p class="text-xs text-muted-foreground">{t('ui.apply.where')}</p>
            <ErrorText error={send.error} />
          </div>
          <Button onclick={() => app.close()}>{t('ui.common.cancel')}</Button>
          <Button variant="primary" disabled={!valid || send.busy} onclick={submit}>{t('ui.apply.send')}</Button>
        </div>
      {/if}
    </div>
  </div>
</div>
