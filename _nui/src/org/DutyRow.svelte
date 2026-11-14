<script lang="ts">
  import Toggle from '../components/ui/Toggle.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { minutesSince, span } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Me } from '../lib/types';

  let { me }: { me: Me } = $props();

  const duty = new Action();

  const label = $derived(
    me.onDuty ? t('ui.duty.on_for', span(me.shiftStartedAt ? minutesSince(me.shiftStartedAt, app.now) : 0)) : t('ui.common.off_duty'),
  );

  function toggle(onDuty: boolean) {
    void duty.run(() => fetchNui('setDuty', { onDuty }));
  }
</script>

<div class="flex h-8 shrink-0 items-center gap-2 rounded-md border border-input bg-secondary pr-1 pl-2.5">
  <span class="size-2 shrink-0 rounded-full {me.onDuty ? 'bg-success' : 'bg-muted-foreground'}"></span>
  <span class="flex-1 truncate text-13 font-medium tabular-nums">{label}</span>
  <Toggle size="sm" label={t('ui.common.on_duty')} checked={me.onDuty} disabled={duty.busy} onchange={toggle} />
</div>
<ErrorText error={duty.error} />
