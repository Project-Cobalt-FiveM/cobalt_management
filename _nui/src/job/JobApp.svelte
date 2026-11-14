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
  import { isOpen, pageIcon, pageLabel, jobIcon } from './meta';
  import { t } from '../lib/locale.svelte';
  import type { JobPage, JobSession } from '../lib/types';

  let { session }: { session: JobSession } = $props();

  const nav = $derived(navFor(session));
  const openRequests = $derived(session.requests?.filter(isOpen).length ?? 0);

  function count(page: JobPage): number | undefined {
    return page === 'employees' ? (session.stats?.total ?? session.employees?.length) : undefined;
  }
</script>

<Panel>
  {#snippet rail()}
    <Rail title={session.job.label} subtitle={isManager(session) ? t('ui.job.manager_menu') : t('ui.job.staff_menu')} icon={jobIcon(session.job.type)} logo={session.job.logoUrl}>
      {#each nav.groups as group, index (index)}
        {#if index > 0}<NavDivider />{/if}
        {#each group as page (page)}
          <NavItem
            label={pageLabel(page)}
            icon={pageIcon(page, session.job.type)}
            active={app.jobPage === page}
            count={count(page)}
            badge={page === 'requests' ? openRequests : undefined}
            onclick={() => app.goJob(page)}
          />
        {/each}
      {/each}
      {#if nav.locked.length > 0}
        <NavDivider />
        <p class="px-2.5 pt-1 pb-2 text-xs text-muted-foreground">{t('ui.job.needs_manager')}</p>
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

  {#key app.jobPage}
    {#if app.jobPage === 'overview'}
      <Overview {session} />
    {:else if app.jobPage === 'employees'}
      <Employees {session} />
    {:else if app.jobPage === 'requests'}
      <Requests {session} />
    {:else if app.jobPage === 'society'}
      <Society {session} />
    {:else if app.jobPage === 'vehicles'}
      <Vehicles {session} />
    {:else if app.jobPage === 'announcements'}
      <Announcements {session} />
    {:else if app.jobPage === 'ranks'}
      <Ranks {session} />
    {:else if app.jobPage === 'settings'}
      <Settings {session} />
    {:else}
      <MyJob {session} />
    {/if}
  {/key}
</Panel>
