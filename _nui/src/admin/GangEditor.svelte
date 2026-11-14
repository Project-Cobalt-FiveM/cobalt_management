<script lang="ts">
  import { untrack } from 'svelte';
  import Body from '../components/shell/Body.svelte';
  import Main from '../components/shell/Main.svelte';
  import Button from '../components/ui/Button.svelte';
  import Select from '../components/ui/Select.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { t } from '../lib/locale.svelte';
  import type { AdminGang, AdminSession, GangMember } from '../lib/types';

  let { session, gang, oncreated }: { session: AdminSession; gang: AdminGang | null; oncreated: (name: string | null) => void } = $props();

  const details = new Action();
  const members = new Action();
  const remove = new Action();

  let label = $state('');
  let roster = $state<GangMember[] | null>(null);
  let adding = $state<string | null>(null);
  let deleting = $state(false);

  const gangName = $derived(gang?.name ?? null);

  function seedDrafts() {
    label = gang?.label ?? '';
  }

  $effect.pre(() => {
    void gangName;
    untrack(seedDrafts);
  });

  const ranks = $derived([...(gang?.ranks ?? [])].sort((a, b) => b.grade - a.grade));
  const rankOptions = $derived(ranks.map((rank) => ({ value: rank.grade, label: t('ui.admin.rank_option', rank.grade, rank.name) })));
  const lowest = $derived(ranks.at(-1)?.grade ?? 0);
  const candidates = $derived(
    session.onlinePlayers
      .filter((player) => !roster?.some((member) => member.citizenid === player.citizenid))
      .map((player) => ({ value: player.citizenid, label: player.gangLabel ? t('ui.admin.candidate_in_gang', player.name, player.gangLabel) : player.name })),
  );
  const valid = $derived(label.trim().length >= session.nameLength.min);

  async function loadMembers(name: string) {
    try {
      roster = await fetchNui('admin:members', { name });
    } catch {
      roster = [];
    }
  }

  $effect(() => {
    if (gangName) void loadMembers(gangName);
  });

  async function saveDetails() {
    if (!valid) return;

    const payload = { label: label.trim() };

    if (gang) {
      const name = gang.name;
      await details.run(() => fetchNui('admin:save', { name, ...payload }));
      return;
    }

    const before = new Set(session.gangs.map((entry) => entry.name));
    if (await details.run(() => fetchNui('admin:create', payload))) oncreated(session.gangs.find((entry) => !before.has(entry.name))?.name ?? null);
  }

  async function assign(citizenid: string, grade: number) {
    if (!gang) return;

    const name = gang.name;
    if (await members.run(() => fetchNui('admin:assign', { name, citizenid, grade }))) await loadMembers(name);
  }

  async function add() {
    if (!adding) return;

    const citizenid = adding;
    adding = null;
    await assign(citizenid, lowest);
  }

  async function kick(citizenid: string) {
    if (!gang) return;

    const name = gang.name;
    if (await members.run(() => fetchNui('admin:remove', { name, citizenid }))) await loadMembers(name);
  }

  async function confirmDelete() {
    if (!gang) return;

    const name = gang.name;
    if (await remove.run(() => fetchNui('admin:delete', { name }))) {
      deleting = false;
      oncreated(null);
    }
  }
</script>

<Body>
  <div class="flex w-105 shrink-0 flex-col gap-4 border-r border-border px-6 pt-7 pb-6">
    <h2 class="text-base font-semibold">{t('ui.admin.details')}</h2>

    <label class="flex flex-col gap-2">
      <span class="text-sm font-semibold">{t('ui.admin.display_name')}</span>
      <input class="field" placeholder={t('ui.admin.name_placeholder')} maxlength={session.nameLength.max} bind:value={label} oninput={() => details.clear()} />
    </label>

    <div>
      <Button variant="primary" disabled={!valid || details.busy} onclick={saveDetails}>
        {gang ? t('ui.admin.save_details') : t('ui.admin.create_gang')}
      </Button>
    </div>
    <ErrorText error={details.error} />

    {#if gang}
      <div class="mt-auto flex flex-col gap-2">
        <Button variant="destructive" class="w-full" onclick={() => (deleting = true)}>{t('ui.admin.delete_gang')}</Button>
        <p class="text-xs text-muted-foreground">{t('ui.admin.delete_hint')}</p>
      </div>
    {/if}
  </div>

  <Main class="gap-4 px-6">
    <div class="flex items-center gap-2">
      <h2 class="flex-1 text-base font-semibold">{t('ui.admin.members')}</h2>
      {#if gang}
        <Select class="w-65" label={t('ui.admin.online_player')} placeholder={t('ui.admin.pick_online')} options={candidates} bind:value={adding} />
        <Button disabled={!adding || members.busy} onclick={add}>{t('ui.admin.add')}</Button>
      {/if}
    </div>

    {#if !gang}
      <p class="text-13 text-muted-foreground">{t('ui.admin.create_first')}</p>
    {:else if roster === null}
      <p class="text-13 text-muted-foreground">{t('ui.admin.loading_members')}</p>
    {:else}
      <div class="flex flex-col overflow-clip rounded-lg border border-border">
        <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
          <span class="flex-1">{t('ui.common.member')}</span>
          <span class="w-45 shrink-0">{t('ui.common.rank')}</span>
          <span class="w-20 shrink-0"></span>
        </div>
        {#each [...roster].sort((a, b) => b.grade - a.grade) as member (member.citizenid)}
          <div class="flex items-center gap-4 border-b border-border px-4 py-2.5 last:border-b-0">
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="truncate text-sm font-semibold">{member.name}</span>
              <span class="truncate text-xs text-muted-foreground tabular-nums">{member.citizenid}</span>
            </span>
            <Select
              class="w-45 shrink-0 [&_.field]:h-8"
              label={t('ui.admin.rank_for', member.name)}
              options={rankOptions}
              value={member.grade}
              disabled={members.busy}
              onchange={(grade) => assign(member.citizenid, grade)}
            />
            <span class="flex w-20 shrink-0 justify-end">
              <Button size="xs" disabled={members.busy} onclick={() => kick(member.citizenid)}>{t('ui.admin.remove')}</Button>
            </span>
          </div>
        {:else}
          <p class="px-4 py-8 text-center text-13 text-muted-foreground">{t('ui.admin.no_members')}</p>
        {/each}
      </div>
    {/if}
    <ErrorText error={members.error} />
  </Main>
</Body>

{#if deleting && gang}
  <Dialog title={t('ui.admin.delete_title', gang.label)} description={t('ui.admin.delete_body')} onclose={() => (deleting = false)}>
    <ErrorText error={remove.error} />
    {#snippet actions()}
      <Button onclick={() => (deleting = false)}>{t('ui.common.cancel')}</Button>
      <Button variant="destructive" disabled={remove.busy} onclick={confirmDelete}>{t('ui.admin.delete_gang')}</Button>
    {/snippet}
  </Dialog>
{/if}
