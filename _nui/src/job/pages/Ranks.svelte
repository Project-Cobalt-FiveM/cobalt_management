<script lang="ts">
  import Crown from 'phosphor-svelte/lib/Crown';
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import RankEditor from '../RankEditor.svelte';
  import { money, plural } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import { permissionText, rankPermissions } from '../meta';
  import type { JobSession, Rank } from '../../lib/types';

  let { session }: { session: JobSession } = $props();

  const ranks = $derived([...session.ranks].sort((a, b) => b.grade - a.grade));
  const people = $derived(session.ranks.reduce((total, rank) => total + rank.people, 0));

  let selectedGrade = $state<number | null>(null);

  const selected = $derived(ranks.find((rank) => rank.grade === selectedGrade) ?? ranks.find((rank) => !rank.isBoss) ?? ranks[0] ?? null);

  function can(rank: Rank): string {
    if (rank.isBoss) return t('ui.ranks.everything');
    if (!rank.permissions.includes('open_menu')) return t('ui.ranks.nothing');

    const parts = rankPermissions.filter((permission) => rank.permissions.includes(permission)).map((permission) => permissionText(permission).short);
    return parts.join(', ');
  }
</script>

<TopBar title={t('ui.page.ranks')} subtitle={t('ui.ranks.subtitle', plural(session.ranks.length, 'ui.plural.rank'), plural(people, 'ui.plural.person'))} />

<Body>
  <Main class="gap-4 px-6">
    <div class="flex flex-col overflow-clip rounded-lg border border-border">
      <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
        <span class="w-12 shrink-0">{t('ui.ranks.grade')}</span>
        <span class="w-90 shrink-0">{t('ui.common.rank')}</span>
        <span class="flex-1">{t('ui.ranks.can')}</span>
        <span class="w-20 shrink-0 text-right">{t('ui.ranks.people')}</span>
        <span class="w-20 shrink-0 text-right">{t('ui.common.pay')}</span>
      </div>
      {#each ranks as rank (rank.grade)}
        {@const active = selected?.grade === rank.grade}
        <button
          type="button"
          aria-pressed={active}
          class="flex items-center gap-4 border-b border-border px-4 py-3.5 text-left transition-colors last:border-b-0 {active ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'}"
          onclick={() => (selectedGrade = rank.grade)}
        >
          <span class="w-12 shrink-0 text-13 tabular-nums {active ? '' : 'text-muted-foreground'}">{rank.grade}</span>
          <span class="flex w-90 shrink-0 items-center gap-2 text-sm font-semibold">
            <span class="truncate">{rank.name}</span>
            {#if rank.isBoss}<Crown size="0.875rem" class={active ? 'text-primary-foreground' : 'text-muted-foreground'} />{/if}
          </span>
          <span class="flex-1 truncate text-13 {active ? 'font-medium' : 'text-muted-foreground'}">{can(rank)}</span>
          <span class="w-20 shrink-0 text-right text-13 font-medium tabular-nums">{rank.people}</span>
          <span class="w-20 shrink-0 text-right text-sm font-semibold tabular-nums">{money(rank.pay)}</span>
        </button>
      {/each}
    </div>
    <p class="text-xs text-muted-foreground">{t('ui.ranks.note')}</p>
  </Main>

  {#if selected}
    <Side width="w-105" class="gap-0">
      {#key selected.grade}
        <RankEditor rank={selected} />
      {/key}
    </Side>
  {/if}
</Body>
