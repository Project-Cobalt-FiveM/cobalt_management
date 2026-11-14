<script lang="ts">
  import { onMount } from 'svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import Button from '../components/ui/Button.svelte';
  import Select from '../components/ui/Select.svelte';
  import Checkbox from '../components/ui/Checkbox.svelte';
  import Avatar from '../components/ui/Avatar.svelte';
  import Status from '../components/ui/Status.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { crossfade } from '../lib/motion';
  import { ago, money } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { NearbyPlayer, OrgSession } from '../lib/types';

  let { session, onclose }: { session: OrgSession; onclose: () => void } = $props();

  const hire = new Action();

  let nearby = $state<NearbyPlayer[] | null>(null);
  let pickedId = $state<string | null>(null);
  let citizenid = $state('');
  let asSecondJob = $state(false);
  let sent = $state<{ name: string; rank: string } | null>(null);

  const ranks = $derived([...session.ranks].filter((rank) => session.me.isBoss || rank.grade < session.me.grade).sort((a, b) => a.grade - b.grade));
  const options = $derived(ranks.map((rank) => ({ value: rank.grade, label: t('ui.common.rank_pay', rank.name, money(rank.pay)) })));

  let grade = $state<number | null>(null);

  $effect(() => {
    if (grade === null) grade = ranks[0]?.grade ?? null;
  });

  const typed = $derived(citizenid.trim().toUpperCase());
  const picked = $derived(nearby?.find((player) => player.citizenid === pickedId) ?? null);
  const target = $derived(typed || picked?.citizenid || '');
  const label = $derived(typed ? t('ui.hire.hire_name', typed) : picked ? t('ui.hire.hire_name', picked.name) : t('ui.hire.hire'));

  onMount(async () => {
    try {
      nearby = await fetchNui('nearbyPlayers');
      pickedId = nearby[0]?.citizenid ?? null;
    } catch {
      nearby = [];
    }
  });

  function detail(player: NearbyPlayer): string {
    if (player.appliedAt) return t('ui.hire.applied', ago(player.appliedAt, app.now));
    return player.job ? t('ui.common.works_at', player.job) : t('ui.common.unemployed');
  }

  function pick(player: NearbyPlayer) {
    pickedId = player.citizenid;
    citizenid = '';
    hire.clear();
  }

  async function submit() {
    if (!target || grade === null) return;

    const rank = options.find((option) => option.value === grade)?.label ?? '';
    const offer = { name: typed || picked?.name || target, rank };
    const payload = { citizenid: target, grade, asSecondJob: session.features.secondJobs && asSecondJob };
    if (await hire.run(() => fetchNui('hire', payload))) sent = offer;
  }
</script>

<Dialog
  title={sent ? t('ui.hire.sent_title') : t('ui.hire.title')}
  description={sent ? t('ui.hire.sent', sent.name) : t('ui.hire.description')}
  width="w-[29.75rem]"
  {onclose}
>
  {#if sent}
    <div class="flex items-center gap-3 rounded-lg border border-border bg-muted px-3 py-2.5" in:crossfade>
      <Avatar name={sent.name} />
      <span class="flex min-w-0 flex-1 flex-col gap-0.5">
        <span class="truncate text-sm font-semibold">{sent.name}</span>
        <span class="truncate text-xs text-muted-foreground">{sent.rank}</span>
      </span>
      <Status tone="warning" label={t('ui.common.waiting')} />
    </div>
  {:else}
    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold">{t('ui.hire.nearby')}</span>
        <span class="text-xs text-muted-foreground tabular-nums">{t('ui.common.within_meters', Math.round(session.hireRadius))}</span>
      </div>
      {#if nearby === null}
        <p class="py-3 text-13 text-muted-foreground">{t('ui.common.looking')}</p>
      {:else if nearby.length === 0}
        <p class="rounded-lg border border-border px-3 py-4 text-center text-13 text-muted-foreground">{t('ui.hire.nobody', Math.round(session.hireRadius))}</p>
      {:else}
        <div class="flex max-h-56 flex-col gap-1.5 overflow-y-auto" role="listbox" aria-label={t('ui.hire.nearby_players')}>
          {#each nearby as player (player.citizenid)}
            {@const active = !typed && player.citizenid === pickedId}
            <button
              type="button"
              role="option"
              aria-selected={active}
              class="flex items-center gap-3 rounded-lg border px-3 py-2.5 text-left transition-colors {active ? 'border-primary bg-primary text-primary-foreground' : 'border-border bg-muted hover:bg-secondary'}"
              onclick={() => pick(player)}
            >
              <Avatar name={player.name} inverted={active} />
              <span class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-semibold">{player.name}</span>
                <span class="truncate text-xs {active ? 'text-primary-foreground' : 'text-muted-foreground'}">{detail(player)}</span>
              </span>
              <span class="text-13 font-medium tabular-nums">{t('ui.common.meters', Math.round(player.distance))}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <div class="grid grid-cols-2 gap-3">
      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.hire.citizen_id')}</span>
        <input class="field uppercase placeholder:normal-case" placeholder={t('ui.hire.citizen_placeholder')} maxlength={16} bind:value={citizenid} oninput={() => hire.clear()} />
      </label>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.hire.starting_rank')}</span>
        <Select label={t('ui.hire.starting_rank')} {options} bind:value={grade} />
      </div>
    </div>

    {#if session.features.secondJobs}
      <div class="flex items-start gap-3">
        <div class="pt-0.5"><Checkbox label={t('ui.hire.second_job')} checked={asSecondJob} onchange={(next) => (asSecondJob = next)} /></div>
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium">{t('ui.hire.second_job')}</span>
          <span class="text-xs text-muted-foreground">{t('ui.hire.second_job_hint')}</span>
        </div>
      </div>
    {/if}

    <ErrorText error={hire.error} />
  {/if}

  {#snippet actions()}
    {#if sent}
      <Button onclick={onclose}>{t('ui.common.close')}</Button>
    {:else}
      <Button onclick={onclose}>{t('ui.common.cancel')}</Button>
      <Button variant="primary" disabled={!target || grade === null || hire.busy} onclick={submit}>{label}</Button>
    {/if}
  {/snippet}
</Dialog>
