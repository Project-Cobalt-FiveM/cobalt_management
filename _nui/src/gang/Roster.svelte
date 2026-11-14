<script lang="ts">
  import { onMount } from 'svelte';
  import Crown from 'phosphor-svelte/lib/Crown';
  import TopBar from '../components/shell/TopBar.svelte';
  import Body from '../components/shell/Body.svelte';
  import Main from '../components/shell/Main.svelte';
  import Side from '../components/shell/Side.svelte';
  import Button from '../components/ui/Button.svelte';
  import Select from '../components/ui/Select.svelte';
  import Status from '../components/ui/Status.svelte';
  import Dialog from '../components/ui/Dialog.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { longDate, plural, shortDate } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { GangMember, GangNearby, GangSession } from '../lib/types';

  type Confirm =
    | { kind: 'kick'; member: GangMember }
    | { kind: 'pass'; member: GangMember }
    | { kind: 'leave' }
    | { kind: 'disband' };

  let { session }: { session: GangSession } = $props();

  const invite = new Action();
  const confirmAction = new Action();

  let nearby = $state<GangNearby[] | null>(null);
  let heir = $state<string | null>(null);
  let confirm = $state<Confirm | null>(null);

  const me = $derived(session.me);
  const ranks = $derived([...session.ranks].sort((a, b) => b.grade - a.grade));
  const bossRank = $derived(ranks.find((rank) => rank.isBoss) ?? ranks[0]);
  const nextRank = $derived(ranks.find((rank) => !rank.isBoss));
  const members = $derived([...session.members].sort((a, b) => b.grade - a.grade || a.name.localeCompare(b.name)));
  const canInvite = $derived(me.isBoss || me.permissions.includes('gang_invite'));
  const heirs = $derived(members.filter((member) => member.citizenid !== me.citizenid).map((member) => ({ value: member.citizenid, label: member.name })));
  const heirMember = $derived(members.find((member) => member.citizenid === heir) ?? null);

  async function loadNearby() {
    try {
      nearby = await fetchNui('gang:nearby');
    } catch {
      nearby = [];
    }
  }

  onMount(() => {
    if (canInvite) void loadNearby();
  });

  async function invitePlayer(player: GangNearby) {
    if (await invite.run(() => fetchNui('gang:invite', { serverId: player.serverId }))) void loadNearby();
  }

  async function confirmed() {
    if (!confirm) return;

    const current = confirm;
    const done = await confirmAction.run(() => {
      switch (current.kind) {
        case 'kick':
          return fetchNui('gang:kick', { citizenid: current.member.citizenid });
        case 'pass':
          return fetchNui('gang:passLeadership', { citizenid: current.member.citizenid });
        case 'leave':
          return fetchNui('gang:leave');
        case 'disband':
          return fetchNui('gang:disband');
      }
    });

    if (!done) return;
    confirm = null;
    heir = null;
    if (current.kind === 'leave' || current.kind === 'disband') app.close();
  }

  function closeConfirm() {
    confirm = null;
    confirmAction.clear();
  }

  const bossName = $derived(bossRank?.name ?? t('ui.common.the_boss'));

  const dialog = $derived.by(() => {
    if (!confirm) return null;

    switch (confirm.kind) {
      case 'kick':
        return {
          title: t('ui.roster.kick_title', confirm.member.name),
          description: t('ui.roster.kick_body', confirm.member.name, session.gang.label),
          action: t('ui.roster.kick'),
        };
      case 'pass':
        return {
          title: t('ui.roster.pass_title', confirm.member.name),
          description: nextRank
            ? t('ui.roster.pass_body_drop', confirm.member.name, bossName, nextRank.name)
            : t('ui.roster.pass_body', confirm.member.name, bossName),
          action: t('ui.roster.pass'),
        };
      case 'leave':
        return {
          title: t('ui.roster.leave_title', session.gang.label),
          description: t('ui.roster.leave_body', session.gang.label, me.rank),
          action: t('ui.roster.leave'),
        };
      case 'disband':
        return {
          title: t('ui.roster.disband_title', session.gang.label),
          description: t('ui.roster.disband_body'),
          action: t('ui.roster.disband'),
        };
    }
  });
</script>

<TopBar title={t('ui.gang.nav.roster')} subtitle={t('ui.roster.subtitle', plural(session.members.length, 'ui.plural.member'), longDate(session.gang.foundedAt))} />

<Body>
  <Main class="gap-4 px-6">
    <div class="flex flex-col overflow-clip rounded-lg border border-border">
      <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
        <span class="flex-1">{t('ui.common.member')}</span>
        <span class="w-40 shrink-0">{t('ui.common.rank')}</span>
        <span class="w-30 shrink-0">{t('ui.common.joined')}</span>
        <span class="w-28 shrink-0">{t('ui.common.status')}</span>
        <span class="w-14 shrink-0"></span>
      </div>
      {#each members as member (member.citizenid)}
        <div class="flex min-h-13 items-center gap-4 border-b border-border px-4 py-2.5 last:border-b-0">
          <span class="flex min-w-0 flex-1 items-center gap-2 text-sm font-semibold">
            <span class="truncate">{member.name}</span>
            {#if member.isBoss}<Crown size="0.875rem" class="shrink-0 text-muted-foreground" />{/if}
          </span>
          <span class="w-40 shrink-0 truncate text-13 font-medium">{member.rank}</span>
          <span class="w-30 shrink-0 text-13 text-muted-foreground tabular-nums">{member.joinedAt ? shortDate(member.joinedAt) : ''}</span>
          <span class="w-28 shrink-0"><Status tone={member.online ? 'success' : 'muted'} label={member.online ? t('ui.common.online') : t('ui.common.offline')} /></span>
          <span class="flex w-14 shrink-0 justify-end">
            {#if me.isBoss && !member.isBoss && member.citizenid !== me.citizenid}
              <Button size="xs" onclick={() => (confirm = { kind: 'kick', member })}>{t('ui.roster.kick')}</Button>
            {/if}
          </span>
        </div>
      {/each}
    </div>
    <p class="text-xs text-muted-foreground">{t('ui.roster.crime_xp')}</p>
  </Main>

  <Side class="gap-0">
    {#if canInvite}
      <section class="flex flex-col gap-3">
        <div class="flex items-center gap-4">
          <h2 class="flex-1 text-base font-semibold">{t('ui.roster.invite')}</h2>
          <span class="text-xs text-muted-foreground tabular-nums">{t('ui.roster.invite_range', Math.round(session.inviteRadius))}</span>
        </div>
        {#if nearby === null}
          <p class="text-13 text-muted-foreground">{t('ui.common.looking')}</p>
        {:else if nearby.length === 0}
          <p class="rounded-lg border border-border px-3 py-4 text-center text-13 text-muted-foreground">{t('ui.roster.nobody')}</p>
        {:else}
          <div class="flex flex-col gap-1.5">
            {#each nearby as player (player.serverId)}
              <div class="flex items-center gap-3 rounded-lg border border-border bg-muted px-3 py-2.5">
                <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span class="truncate text-sm font-semibold">{player.name}</span>
                  <span class="truncate text-xs text-muted-foreground tabular-nums">
                    {player.gangLabel
                      ? t('ui.roster.nearby_in_gang', Math.round(player.distance), player.gangLabel)
                      : t('ui.roster.nearby_no_gang', Math.round(player.distance))}
                  </span>
                </div>
                <Button size="xs" variant={player.gangLabel ? 'secondary' : 'primary'} disabled={!!player.gangLabel || invite.busy} onclick={() => invitePlayer(player)}>{t('ui.roster.invite')}</Button>
              </div>
            {/each}
          </div>
        {/if}
        <p class="text-xs text-muted-foreground">{t('ui.roster.other_gang')}</p>
        <ErrorText error={invite.error} />
      </section>
    {/if}

    {#if me.isBoss}
      <section class="mt-6 flex flex-col gap-3 border-t border-border pt-6">
        <div class="flex flex-col gap-1">
          <h2 class="text-base font-semibold">{t('ui.roster.pass')}</h2>
          <p class="text-13 text-muted-foreground">
            {nextRank ? t('ui.roster.pass_hint_drop', bossName, nextRank.name) : t('ui.roster.pass_hint', bossName)}
          </p>
        </div>
        <Select label={t('ui.roster.new_leader')} placeholder={t('ui.common.pick_member')} options={heirs} bind:value={heir} />
        <Button class="w-full" disabled={!heirMember} onclick={() => heirMember && (confirm = { kind: 'pass', member: heirMember })}>{t('ui.roster.pass')}</Button>
      </section>

      <div class="mt-auto pt-6">
        <Button variant="destructive" class="w-full" onclick={() => (confirm = { kind: 'disband' })}>{t('ui.roster.disband')}</Button>
      </div>
    {:else}
      <div class="mt-auto pt-6">
        <Button variant="destructive" class="w-full" onclick={() => (confirm = { kind: 'leave' })}>{t('ui.roster.leave')}</Button>
      </div>
    {/if}
  </Side>
</Body>

{#if confirm && dialog}
  <Dialog title={dialog.title} description={dialog.description} onclose={closeConfirm}>
    <ErrorText error={confirmAction.error} />
    {#snippet actions()}
      <Button onclick={closeConfirm}>{t('ui.common.cancel')}</Button>
      <Button variant={confirm?.kind === 'pass' ? 'primary' : 'destructive'} disabled={confirmAction.busy} onclick={confirmed}>{dialog?.action}</Button>
    {/snippet}
  </Dialog>
{/if}
