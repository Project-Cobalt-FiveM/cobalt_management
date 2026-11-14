<script lang="ts">
  import Button from '../components/ui/Button.svelte';
  import Row from '../components/ui/Row.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { money } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { rise } from '../lib/motion';
  import type { CharterSession } from '../lib/types';

  let { session }: { session: CharterSession } = $props();

  const charter = new Action();

  let label = $state('');

  const name = $derived(label.trim());
  const nameValid = $derived(name.length >= session.nameLength.min && name.length <= session.nameLength.max);
  const short = $derived(Math.max(0, session.price - session.carried));
  const full = $derived(session.slotsUsed >= session.maxSlots);
  const ready = $derived(nameValid && short === 0 && !full);

  const blocker = $derived.by(() => {
    if (full) return t('ui.charter.full');
    if (short > 0) return t('ui.charter.short', money(short));
    return null;
  });

  function focus(node: HTMLInputElement) {
    node.focus();
  }

  async function submit() {
    if (!ready) return;

    const payload = { label: name };
    if (await charter.run(() => fetchNui('charter:send', payload))) app.close();
  }
</script>

<div class="fixed inset-y-0 right-56 flex items-center">
  <div class="flex w-115 flex-col gap-5 rounded-lg border border-border bg-popover p-6 shadow-lg" role="dialog" aria-modal="true" aria-label={t('ui.charter.title')} transition:rise={{ duration: 200 }}>
    <div class="flex flex-col gap-1.5">
      <h2 class="text-lg font-semibold tracking-tight">{t('ui.charter.title')}</h2>
      <p class="text-sm text-muted-foreground">{t('ui.charter.intro', session.bossRank)}</p>
    </div>

    <label class="flex flex-col gap-2">
      <span class="text-sm font-semibold">{t('ui.charter.name')}</span>
      <input use:focus class="field" placeholder={t('ui.charter.name')} maxlength={session.nameLength.max} bind:value={label} oninput={() => charter.clear()} />
      <span class="text-xs text-muted-foreground">{t('ui.charter.name_hint', session.nameLength.min, session.nameLength.max)}</span>
    </label>

    <div class="flex flex-col border-t border-border">
      <Row label={t('ui.charter.price')}>{t('ui.charter.bills', money(session.price))}</Row>
      <Row label={t('ui.charter.carry')}><span class={short > 0 ? 'text-destructive' : ''}>{t('ui.charter.bills', money(session.carried))}</span></Row>
      <Row label={t('ui.charter.slots')}>{t('ui.charter.slots_taken', session.slotsUsed, session.maxSlots)}</Row>
    </div>

    {#if blocker}<p class="text-xs text-muted-foreground">{blocker}</p>{/if}
    <ErrorText error={charter.error} />

    <div class="flex justify-end gap-2">
      <Button onclick={() => app.close()}>{t('ui.charter.not_now')}</Button>
      <Button variant="primary" disabled={!ready || charter.busy} onclick={submit}>{t('ui.charter.pay', money(session.price))}</Button>
    </div>
  </div>
</div>
