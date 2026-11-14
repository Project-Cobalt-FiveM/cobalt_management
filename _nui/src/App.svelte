<script lang="ts">
  import { onMount } from 'svelte';
  import IconContext from 'phosphor-svelte/lib/IconContext';
  import { inGame, mockOpen, onMessage } from './lib/nui';
  import { app, type GangPage } from './lib/store.svelte';
  import type { OrgPage } from './lib/types';
  import OrgApp from './org/OrgApp.svelte';
  import GangApp from './gang/GangApp.svelte';
  import AdminApp from './admin/AdminApp.svelte';
  import ApplyDialog from './apply/ApplyDialog.svelte';
  import CharterDialog from './charter/CharterDialog.svelte';

  const orgPages: ReadonlySet<string> = new Set<OrgPage>(['overview', 'employees', 'requests', 'society', 'vehicles', 'announcements', 'ranks', 'settings', 'myJob', 'myJobs']);
  const gangPages: ReadonlySet<string> = new Set<GangPage>(['roster', 'permissions', 'vault', 'archetype']);

  function isOrgPage(value: string): value is OrgPage {
    return orgPages.has(value);
  }

  function isGangPage(value: string): value is GangPage {
    return gangPages.has(value);
  }

  function onkeydown(event: KeyboardEvent) {
    if (!app.visible || event.key !== 'Escape') return;

    event.preventDefault();
    app.escape();
  }

  onMount(() => {
    const stop = onMessage((message) => app.handle(message));

    void mockOpen().then((mock) => {
      if (!mock) return;

      app.handle(mock.message);
      if (mock.page && isOrgPage(mock.page)) app.goOrg(mock.page);
      if (mock.page && isGangPage(mock.page)) app.goGang(mock.page);
    });

    if (!inGame) window.addEventListener('hashchange', () => location.reload());

    return stop;
  });
</script>

<svelte:window {onkeydown} />

<IconContext values={{ weight: 'fill' }}>
  {#if app.visible && app.session}
    {#if app.session.mode === 'org'}
      <OrgApp session={app.session} />
    {:else if app.session.mode === 'gang'}
      <GangApp session={app.session} />
    {:else if app.session.mode === 'gangAdmin'}
      <AdminApp session={app.session} />
    {:else if app.session.mode === 'apply'}
      <ApplyDialog session={app.session} />
    {:else}
      <CharterDialog session={app.session} />
    {/if}
  {/if}
</IconContext>
