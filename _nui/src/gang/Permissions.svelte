<script lang="ts">
  import TopBar from '../components/shell/TopBar.svelte';
  import Body from '../components/shell/Body.svelte';
  import Main from '../components/shell/Main.svelte';
  import Button from '../components/ui/Button.svelte';
  import Checkbox from '../components/ui/Checkbox.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { plural } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { GangPermission, GangRank, GangSession } from '../lib/types';

  let { session }: { session: GangSession } = $props();

  const save = new Action();
  const reset = new Action();

  let draft = $state<Record<string, GangPermission[]>>({});

  $effect.pre(() => {
    draft = $state.snapshot(session.permissions);
  });

  const ranks = $derived([...session.ranks].sort((a, b) => a.grade - b.grade));
  const boss = $derived(ranks.find((rank) => rank.isBoss));

  function granted(source: Record<string, GangPermission[]>, rank: GangRank, id: GangPermission): boolean {
    return rank.isBoss || (source[String(rank.grade)] ?? []).includes(id);
  }

  const changes = $derived(
    session.permissionCatalog.reduce(
      (total, permission) => total + ranks.filter((rank) => !rank.isBoss && granted(draft, rank, permission.id) !== granted(session.permissions, rank, permission.id)).length,
      0,
    ),
  );

  function set(rank: GangRank, id: GangPermission, on: boolean) {
    const key = String(rank.grade);
    const current = draft[key] ?? [];
    draft[key] = on ? [...current, id] : current.filter((entry) => entry !== id);
    save.clear();
  }

  function submit() {
    const permissions = Object.fromEntries(ranks.filter((rank) => !rank.isBoss).map((rank) => [String(rank.grade), [...(draft[String(rank.grade)] ?? [])]]));
    void save.run(() => fetchNui('gang:savePermissions', { permissions }));
  }
</script>

<TopBar title={t('ui.gang.nav.permissions')} subtitle={t('ui.permissions.subtitle')} />

<Body>
  <Main class="gap-4 px-6">
    <div class="flex flex-col overflow-clip rounded-lg border border-border">
      <div class="flex items-center border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
        <span class="flex-1">{t('ui.permissions.permission')}</span>
        {#each ranks as rank (rank.grade)}
          <span class="w-24 shrink-0 truncate text-center">{rank.name}</span>
        {/each}
      </div>
      {#each session.permissionCatalog as permission (permission.id)}
        <div class="flex items-center border-b border-border px-4 py-2.5 last:border-b-0">
          <span class="flex-1 truncate text-sm font-medium">{permission.label}</span>
          {#each ranks as rank (rank.grade)}
            <span class="flex w-24 shrink-0 justify-center">
              <Checkbox
                label={t('ui.permissions.checkbox', permission.label, rank.name)}
                checked={granted(draft, rank, permission.id)}
                disabled={rank.isBoss}
                onchange={(on) => set(rank, permission.id, on)}
              />
            </span>
          {/each}
        </div>
      {/each}
    </div>

    <div class="flex items-center gap-3">
      <p class="flex-1 text-xs text-muted-foreground">
        {t('ui.permissions.boss_note', boss?.name ?? t('ui.permissions.boss_rank'))}
      </p>
      {#if changes > 0}<span class="text-xs text-muted-foreground tabular-nums">{plural(changes, 'ui.plural.unsaved_change')}</span>{/if}
      <Button disabled={reset.busy} onclick={() => reset.run(() => fetchNui('gang:resetPermissions'))}>{t('ui.permissions.reset')}</Button>
      <Button variant="primary" disabled={changes === 0 || save.busy} onclick={submit}>{t('ui.permissions.save')}</Button>
    </div>
    <ErrorText error={save.error ?? reset.error} class="text-right" />
  </Main>
</Body>
