<script lang="ts">
  import ShieldCheck from 'phosphor-svelte/lib/ShieldCheck';
  import PlusSquare from 'phosphor-svelte/lib/PlusSquare';
  import Panel from '../components/shell/Panel.svelte';
  import Rail from '../components/shell/Rail.svelte';
  import MeCard from '../components/shell/MeCard.svelte';
  import TopBar from '../components/shell/TopBar.svelte';
  import Button from '../components/ui/Button.svelte';
  import GangEditor from './GangEditor.svelte';
  import { longDate } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { AdminSession } from '../lib/types';

  let { session }: { session: AdminSession } = $props();

  let selectedName = $state<string | null>(null);
  let creating = $state(false);

  const gangs = $derived(session.gangs);
  const selected = $derived(creating ? null : (gangs.find((gang) => gang.name === selectedName) ?? gangs[0] ?? null));
  const full = $derived(session.gangs.length >= session.maxGangs);

  function colour(id: number): string {
    return session.colours.find((entry) => entry.id === id)?.hex ?? '#a3a3a3';
  }

  function pick(name: string) {
    creating = false;
    selectedName = name;
  }

  function created(name: string | null) {
    creating = false;
    selectedName = name;
  }
</script>

<Panel>
  {#snippet rail()}
    <Rail title={t('ui.admin.title')} subtitle={t('ui.admin.subtitle')} icon={ShieldCheck}>
      <Button class="mb-3 w-full" disabled={full} onclick={() => (creating = true)}><PlusSquare size="1rem" />{t('ui.admin.new_gang')}</Button>
      {#each gangs as gang (gang.name)}
        {@const active = selected?.name === gang.name}
        <button
          type="button"
          aria-current={active ? 'page' : undefined}
          class="flex h-10 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-left text-sm font-semibold transition-colors {active ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'}"
          onclick={() => pick(gang.name)}
        >
          <span class="size-2 shrink-0 rounded-full" style:background-color={colour(gang.blipColor)}></span>
          <span class="flex-1 truncate">{gang.label}</span>
          <span class="text-xs font-normal tabular-nums {active ? 'text-primary-foreground' : 'text-muted-foreground'}">{gang.members}</span>
        </button>
      {/each}
      <p class="px-2.5 pt-2 text-xs text-muted-foreground tabular-nums">{t('ui.admin.slots_used', session.gangs.length, session.maxGangs)}</p>

      {#snippet footer()}
        <MeCard name={session.admin.name} detail={session.admin.rank} />
      {/snippet}
    </Rail>
  {/snippet}

  {#if selected}
    <TopBar
      title={selected.label}
      subtitle={selected.founderName
        ? t('ui.admin.founded_by', selected.founderName, longDate(selected.foundedAt))
        : t('ui.admin.founded', longDate(selected.foundedAt))}
    />
  {:else}
    <TopBar title={t('ui.admin.new_gang')} subtitle={full ? t('ui.admin.slots_full') : t('ui.admin.new_hint')} />
  {/if}

  {#key selected?.name ?? 'new'}
    <GangEditor {session} gang={selected} oncreated={created} />
  {/key}
</Panel>
