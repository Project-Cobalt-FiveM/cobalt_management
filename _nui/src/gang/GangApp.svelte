<script lang="ts">
  import Flag from 'phosphor-svelte/lib/Flag';
  import UsersThree from 'phosphor-svelte/lib/UsersThree';
  import ShieldCheck from 'phosphor-svelte/lib/ShieldCheck';
  import Vault from 'phosphor-svelte/lib/Vault';
  import Panel from '../components/shell/Panel.svelte';
  import Rail from '../components/shell/Rail.svelte';
  import NavItem from '../components/shell/NavItem.svelte';
  import MeCard from '../components/shell/MeCard.svelte';
  import Roster from './Roster.svelte';
  import Permissions from './Permissions.svelte';
  import GangVault from './GangVault.svelte';
  import { app, type GangPage } from '../lib/store.svelte';
  import { t } from '../lib/locale.svelte';
  import type { GangSession } from '../lib/types';
  import type { Icon } from '../components/ui/types';

  let { session }: { session: GangSession } = $props();

  const items = $derived<{ page: GangPage; label: string; icon: Icon; count?: number }[]>([
    { page: 'roster', label: t('ui.gang.nav.roster'), icon: UsersThree, count: session.members.length },
    ...(session.me.isBoss ? [{ page: 'permissions' as const, label: t('ui.gang.nav.permissions'), icon: ShieldCheck }] : []),
    { page: 'vault', label: t('ui.gang.nav.vault'), icon: Vault },
  ]);

  const page = $derived(items.some((item) => item.page === app.gangPage) ? app.gangPage : 'roster');
</script>

<Panel>
  {#snippet rail()}
    <Rail title={session.gang.label} subtitle={t('ui.gang.subtitle')} icon={Flag}>
      {#each items as item (item.page)}
        <NavItem label={item.label} icon={item.icon} active={page === item.page} count={item.count} onclick={() => app.goGang(item.page)} />
      {/each}

      {#snippet footer()}
        <MeCard name={session.me.name} detail={session.me.isFounder ? t('ui.gang.rank_founder', session.me.rank) : session.me.rank} />
      {/snippet}
    </Rail>
  {/snippet}

  {#key page}
    {#if page === 'roster'}
      <Roster {session} />
    {:else if page === 'permissions'}
      <Permissions {session} />
    {:else}
      <GangVault {session} />
    {/if}
  {/key}
</Panel>
