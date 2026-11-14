<script lang="ts">
  import Dialog from '../components/ui/Dialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { firstName } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Employee, OrgSession } from '../lib/types';

  let { session, employee, onclose }: { session: OrgSession; employee: Employee; onclose: () => void } = $props();

  const fire = new Action();

  let reason = $state('');

  const name = $derived(firstName(employee.name));
  const description = $derived(
    session.features.duty ? t('ui.fire.body_duty', name, session.org.label, name) : t('ui.fire.body', name, session.org.label),
  );

  function focus(node: HTMLInputElement) {
    node.focus();
  }

  async function submit() {
    if (await fire.run(() => fetchNui('fire', { citizenid: employee.citizenid, reason: reason.trim() }))) onclose();
  }
</script>

<Dialog title={t('ui.fire.title', employee.name)} {description} width="w-[27.5rem]" {onclose}>
  <label class="flex flex-col gap-2">
    <span class="text-sm font-semibold">{t('ui.common.reason')}</span>
    <input use:focus class="field" placeholder={t('ui.fire.placeholder')} maxlength={session.limits.reason} bind:value={reason} />
    <span class="text-xs text-muted-foreground">{t('ui.fire.hint')}</span>
  </label>
  <ErrorText error={fire.error} />

  {#snippet actions()}
    <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
    <Button variant="destructive" disabled={fire.busy} onclick={submit}>{t('ui.employee.fire', name)}</Button>
  {/snippet}
</Dialog>
