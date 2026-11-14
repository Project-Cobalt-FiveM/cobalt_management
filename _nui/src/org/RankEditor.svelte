<script lang="ts">
  import Button from '../components/ui/Button.svelte';
  import Checkbox from '../components/ui/Checkbox.svelte';
  import MoneyInput from '../components/ui/MoneyInput.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { permissionText, rankPermissions } from './meta';
  import type { Rank, RankPermission } from '../lib/types';

  let { rank }: { rank: Rank } = $props();

  const save = new Action();

  let pay = $state<number | null>(null);
  let granted = $state<RankPermission[]>([]);

  $effect.pre(() => {
    pay = rank.pay;
    granted = [...rank.permissions];
  });

  const changes = $derived(
    (pay !== rank.pay ? 1 : 0) + rankPermissions.filter((permission) => granted.includes(permission) !== rank.permissions.includes(permission)).length,
  );

  function has(permission: RankPermission): boolean {
    return rank.isBoss || granted.includes(permission);
  }

  function set(permission: RankPermission, on: boolean) {
    granted = on ? [...granted, permission] : granted.filter((entry) => entry !== permission);
    save.clear();
  }

  function discard() {
    pay = rank.pay;
    granted = [...rank.permissions];
    save.clear();
  }

  function submit() {
    if (pay === null) return;

    const payload = { grade: rank.grade, pay, permissions: rankPermissions.filter((permission) => granted.includes(permission)) };
    void save.run(() => fetchNui('saveRank', payload));
  }
</script>

<div class="flex flex-col gap-1">
  <span class="text-13 text-muted-foreground tabular-nums">{t('ui.rank.subtitle', rank.grade, plural(rank.people, 'ui.plural.person'))}</span>
  <h2 class="text-xl leading-7 font-semibold tracking-[-0.01em]">{rank.name}</h2>
</div>

<div class="mt-6 flex flex-col gap-2">
  <span class="text-sm font-semibold">{t('ui.common.pay_per_payday')}</span>
  <MoneyInput label={t('ui.common.pay_per_payday')} bind:value={pay} oninput={() => save.clear()} />
  <p class="text-xs text-muted-foreground">{t('ui.rank.pay_hint', rank.name.toLowerCase())}</p>
</div>

<div class="mt-6 flex flex-col gap-2">
  <span class="text-sm font-semibold">{t('ui.rank.can_do')}</span>
  <div class="flex flex-col rounded-lg border border-border">
    {#each rankPermissions as permission (permission)}
      {@const text = permissionText(permission)}
      <div class="flex items-start gap-3 border-b border-border px-6 py-3 last:border-b-0">
        <div class="pt-0.5">
          <Checkbox label={text.title} checked={has(permission)} disabled={rank.isBoss} onchange={(on) => set(permission, on)} />
        </div>
        <div class="flex min-w-0 flex-col gap-0.5">
          <span class="text-sm font-medium">{text.title}</span>
          <span class="text-xs text-muted-foreground">{text.body}</span>
        </div>
      </div>
    {/each}
  </div>
  {#if rank.isBoss}<p class="text-xs text-muted-foreground">{t('ui.rank.boss_all')}</p>{/if}
</div>

<div class="mt-auto flex items-center gap-2 pt-6">
  <div class="flex min-w-0 flex-1 flex-col gap-1">
    {#if changes > 0}<span class="text-xs text-muted-foreground tabular-nums">{plural(changes, 'ui.plural.unsaved_change')}</span>{/if}
    <ErrorText error={save.error} />
  </div>
  <Button disabled={changes === 0 || save.busy} onclick={discard}>{t('ui.rank.discard')}</Button>
  <Button variant="primary" disabled={changes === 0 || pay === null || save.busy} onclick={submit}>{t('ui.rank.save')}</Button>
</div>
