<script lang="ts">
  import UserPlus from 'phosphor-svelte/lib/UserPlus';
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Tabs from '../../components/ui/Tabs.svelte';
  import Button from '../../components/ui/Button.svelte';
  import RequestDetail from '../RequestDetail.svelte';
  import HireDialog from '../HireDialog.svelte';
  import owl from '../../assets/owl.png';
  import { app } from '../../lib/store.svelte';
  import { age } from '../../lib/format';
  import { isOpen } from '../meta';
  import { kindIcons, preview } from '../requests';
  import { t } from '../../lib/locale.svelte';
  import type { JobSession, RequestKind } from '../../lib/types';
  import type { Tab } from '../../components/ui/types';

  type View = 'open' | RequestKind;

  let { session }: { session: JobSession } = $props();

  let view = $state<View>('open');
  let selectedId = $state<number | null>(null);
  let hiring = $state(false);

  const requests = $derived(session.requests ?? []);
  const kinds = $derived(
    (
      [
        ['application', session.features.applications],
        ['leave', session.features.leaves],
        ['report', session.features.reports],
      ] satisfies [RequestKind, boolean][]
    )
      .filter(([, on]) => on)
      .map(([kind]) => kind),
  );

  function openCount(kind: RequestKind): number {
    return requests.filter((request) => request.kind === kind && isOpen(request)).length;
  }

  const tabs = $derived<Tab<View>[]>([
    { value: 'open', label: t('ui.requests.open'), count: requests.filter(isOpen).length },
    ...kinds.map((kind) => ({ value: kind, label: t(`ui.requests.kind.${kind}`), count: openCount(kind) || undefined })),
  ]);

  const shown = $derived(
    view === 'open'
      ? requests.filter(isOpen)
      : requests.filter((request) => request.kind === view).sort((a, b) => Number(isOpen(b)) - Number(isOpen(a))),
  );

  const selected = $derived(shown.find((request) => request.id === selectedId) ?? shown[0] ?? null);
  const answeredKind = $derived(kinds.find((kind) => requests.some((request) => request.kind === kind)) ?? null);
  const emptyTitle = $derived(view === 'open' ? t('ui.common.nothing_waiting') : t(`ui.requests.none.${view}`));
</script>

<TopBar title={t('ui.page.requests')} subtitle={t('ui.requests.subtitle')} />

{#if shown.length === 0}
  <Body>
    <div class="flex flex-1 flex-col px-6 pt-7 pb-6">
      <Tabs {tabs} bind:value={view} />
      <div class="flex flex-1 flex-col items-center justify-center gap-5 pb-15">
        <img src={owl} alt="" class="size-35 mix-blend-lighten" />
        <div class="flex w-105 flex-col items-center gap-1.5 text-center">
          <h2 class="text-xl leading-7 font-semibold tracking-[-0.01em]">{emptyTitle}</h2>
          <p class="text-sm text-muted-foreground">
            {t('ui.requests.empty_body')}
            {#if session.features.applications}{t('ui.requests.empty_apply')}{/if}
          </p>
        </div>
        <div class="flex gap-2">
          {#if view === 'open' && answeredKind}
            <Button onclick={() => (view = answeredKind)}>{t('ui.requests.see_answered')}</Button>
          {/if}
          {#if session.access.manageStaff}
            <Button variant="primary" onclick={() => (hiring = true)}><UserPlus size="1rem" />{t('ui.requests.hire_nearby')}</Button>
          {/if}
        </div>
      </div>
    </div>
  </Body>
{:else}
  <Body>
    <div class="flex w-115 shrink-0 flex-col gap-4 border-r border-border px-6 pt-7 pb-6">
      <Tabs {tabs} bind:value={view} />
      <div class="-mx-1 flex min-h-0 flex-1 flex-col gap-1.5 overflow-y-auto px-1">
        {#each shown as request (request.id)}
          {@const active = selected?.id === request.id}
          {@const Glyph = kindIcons[request.kind]}
          <button
            type="button"
            aria-pressed={active}
            class="flex shrink-0 items-start gap-3 rounded-lg border px-4 py-3 text-left transition-colors {active
              ? 'border-primary bg-primary text-primary-foreground'
              : 'border-border hover:bg-muted'}"
            onclick={() => (selectedId = request.id)}
          >
            <Glyph size="1rem" class="mt-0.5 shrink-0 {active ? 'text-primary-foreground' : 'text-muted-foreground'}" />
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="flex items-center gap-3">
                <span class="flex-1 truncate text-sm font-semibold">{request.name}</span>
                <span class="shrink-0 text-xs tabular-nums {active ? 'text-primary-foreground' : 'text-muted-foreground'}">
                  {isOpen(request) ? age(request.createdAt, app.now) : request.status === 'approved' ? t('ui.common.approved') : t('ui.common.declined')}
                </span>
              </span>
              <span class="truncate text-13 {active ? 'text-primary-foreground' : 'text-muted-foreground'}">{preview(request)}</span>
            </span>
          </button>
        {/each}
      </div>
      <p class="text-xs text-muted-foreground">{t('ui.requests.answered_note')}</p>
    </div>

    {#if selected}
      {#key selected.id}
        <RequestDetail {session} request={selected} />
      {/key}
    {/if}
  </Body>
{/if}

{#if hiring}
  <HireDialog {session} onclose={() => (hiring = false)} />
{/if}
