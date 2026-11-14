<script lang="ts">
  import Dialog from '../components/ui/Dialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Row from '../components/ui/Row.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { money } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { OrgSession, Society } from '../lib/types';

  type Props = { session: OrgSession; society: Society; amount: number; note: string; onclose: () => void; ondone: () => void };

  let { session, society, amount, note, onclose, ondone }: Props = $props();

  const withdraw = new Action();

  const after = $derived(society.balance - amount);
  const covered = $derived(society.payroll > 0 ? { now: Math.floor(society.balance / society.payroll), after: Math.floor(after / society.payroll) } : null);

  async function submit() {
    if (await withdraw.run(() => fetchNui('withdraw', { amount, note: note.trim() }))) {
      ondone();
      onclose();
    }
  }
</script>

<Dialog
  title={t('ui.withdraw.title', money(amount))}
  description={t('ui.withdraw.body', session.org.label)}
  width="w-[27.5rem]"
  {onclose}
>
  <div class="flex flex-col border-t border-border">
    <Row label={t('ui.withdraw.after')}>{money(after)}</Row>
    {#if covered}
      <Row label={t('ui.withdraw.paydays')}>{t('ui.withdraw.down_from', covered.after, covered.now)}</Row>
    {/if}
    {#if note.trim()}
      <Row label={t('ui.society.note')}>{note.trim()}</Row>
    {/if}
  </div>
  <ErrorText error={withdraw.error} />

  {#snippet actions()}
    <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
    <Button variant="primary" disabled={withdraw.busy} onclick={submit}>{t('ui.withdraw.confirm', money(amount))}</Button>
  {/snippet}
</Dialog>
