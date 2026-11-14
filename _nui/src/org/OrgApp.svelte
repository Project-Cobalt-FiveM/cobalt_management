<script lang="ts">
  import Panel from '../components/shell/Panel.svelte';
  import Rail from '../components/shell/Rail.svelte';
  import NavItem from '../components/shell/NavItem.svelte';
  import NavDivider from '../components/shell/NavDivider.svelte';
  import LockedItem from '../components/shell/LockedItem.svelte';
  import MeCard from '../components/shell/MeCard.svelte';
  import DutyRow from './DutyRow.svelte';
  import Overview from './pages/Overview.svelte';
  import Employees from './pages/Employees.svelte';
  import Requests from './pages/Requests.svelte';
  import Society from './pages/Society.svelte';
  import Vehicles from './pages/Vehicles.svelte';
  import Announcements from './pages/Announcements.svelte';
  import Ranks from './pages/Ranks.svelte';
  import Settings from './pages/Settings.svelte';
  import MyJob from './pages/MyJob.svelte';
  import { app } from '../lib/store.svelte';
  import { isManager, navFor } from '../lib/access';
  import { isOpen, pageIcon, pageLabel, orgIcon } from './meta';
  import { t } from '../lib/locale.svelte';
  import type { OrgPage, OrgSession } from '../lib/types';

  let { session }: { session: OrgSession } = $props();

  const nav = $derived(navFor(session));
  const openRequests = $derived(session.requests?.filter(isOpen).length ?? 0);

  function count(page: OrgPage): number | undefined {
    return page === 'employees' ? (session.stats?.total ?? session.employees?.length) : undefined;
  }
</script>

<Panel>
  {#snippet rail()}
    <Rail title={session.org.label} subtitle={isManager(session) ? t('ui.org.manager_menu') : t('ui.org.staff_menu')} icon={orgIcon(session.org.type)} logo={session.org.logoUrl}>
      {#each nav.groups as group, index (index)}
        {#if index > 0}<NavDivider />{/if}
        {#each group as page (page)}
          <NavItem
            label={pageLabel(page)}
            icon={pageIcon(page, session.org.type)}
            active={app.orgPage === page}
            count={count(page)}
            badge={page === 'requests' ? openRequests : undefined}
            onclick={() => app.goOrg(page)}
          />
        {/each}
      {/each}
      {#if nav.locked.length > 0}
        <NavDivider />
        <p class="px-2.5 pt-1 pb-2 text-xs text-muted-foreground">{t('ui.org.needs_manager')}</p>
        {#each nav.locked as page (page)}
          <LockedItem label={pageLabel(page)} />
        {/each}
      {/if}

      {#snippet footer()}
        <MeCard name={session.me.name} detail={session.me.rank}>
          {#if session.features.duty}<DutyRow me={session.me} />{/if}
        </MeCard>
      {/snippet}
    </Rail>
  {/snippet}

  {#key app.orgPage}
    {#if app.orgPage === 'overview'}
      <Overview {session} />
    {:else if app.orgPage === 'employees'}
      <Employees {session} />
    {:else if app.orgPage === 'requests'}
      <Requests {session} />
    {:else if app.orgPage === 'society'}
      <Society {session} />
    {:else if app.orgPage === 'vehicles'}
      <Vehicles {session} />
    {:else if app.orgPage === 'announcements'}
      <Announcements {session} />
    {:else if app.orgPage === 'ranks'}
      <Ranks {session} />
    {:else if app.orgPage === 'settings'}
      <Settings {session} />
    {:else}
      <MyJob {session} />
    {/if}
  {/key}
</Panel>
