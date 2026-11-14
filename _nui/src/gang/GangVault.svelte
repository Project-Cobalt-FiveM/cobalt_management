<script lang="ts">
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import TopBar from '../components/shell/TopBar.svelte';
  import Body from '../components/shell/Body.svelte';
  import Main from '../components/shell/Main.svelte';
  import Side from '../components/shell/Side.svelte';
  import Button from '../components/ui/Button.svelte';
  import Select from '../components/ui/Select.svelte';
  import MoneyInput from '../components/ui/MoneyInput.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action, app } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { ago, isFuture, money, plural, signedMoney, stamp, wait } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { GangSession } from '../lib/types';

  let { session }: { session: GangSession } = $props();

  const withdraw = new Action();
  const turf = new Action();
  const hq = new Action();

  let amount = $state<number | null>(null);
  let zone = $state<string | null>(null);

  const storedZone = $derived(session.turf.zone ?? null);

  $effect.pre(() => {
    zone = storedZone;
  });

  const vault = $derived(session.vault);
  const tooMuch = $derived(amount !== null && amount > vault.balance);
  const zones = $derived(session.turf.zones.map((entry) => ({ value: entry.id, label: entry.label })));
  const turfWait = $derived(isFuture(session.turf.cooldownEndsAt, app.now) ? session.turf.cooldownEndsAt : null);
  const hqWait = $derived(isFuture(session.hq.cooldownEndsAt, app.now) ? session.hq.cooldownEndsAt : null);

  async function takeOut() {
    if (amount === null || tooMuch) return;

    const value = amount;
    if (await withdraw.run(() => fetchNui('gang:withdraw', { amount: value }))) amount = null;
  }

  function moveTurf() {
    if (!zone) return;

    const target = zone;
    void turf.run(() => fetchNui('gang:moveTurf', { zone: target }));
  }
</script>

<TopBar title={t('ui.gang.nav.vault')} subtitle={t('ui.vault.subtitle')} />

<Body>
  <Main class="gap-7 px-6">
    {#if vault.canSee}
      <div class="flex items-end gap-6">
        <div class="flex flex-1 flex-col gap-1.5">
          <span class="text-13 font-medium text-muted-foreground">{t('ui.vault.balance')}</span>
          <span class="text-[2.75rem] leading-12 font-semibold tracking-[-0.02em] tabular-nums">{money(vault.balance)}</span>
          <p class="text-sm text-muted-foreground">{t('ui.vault.deposits')}</p>
        </div>
        {#if vault.canWithdraw}
          <div class="flex shrink-0 flex-col items-end gap-1.5">
            <div class="flex gap-2">
              <MoneyInput class="w-45" label={t('ui.vault.withdraw_amount')} bind:value={amount} oninput={() => withdraw.clear()} />
              <Button variant="primary" disabled={amount === null || amount <= 0 || tooMuch || withdraw.busy} onclick={takeOut}>{t('ui.vault.withdraw')}</Button>
            </div>
            {#if tooMuch}<p class="text-xs text-destructive">{t('ui.vault.holds', money(vault.balance))}</p>{/if}
            <ErrorText error={withdraw.error} />
          </div>
        {/if}
      </div>
    {:else}
      <div class="flex flex-col gap-1.5">
        <span class="text-13 font-medium text-muted-foreground">{t('ui.vault.balance')}</span>
        <p class="text-sm text-muted-foreground">{t('ui.vault.hidden')}</p>
      </div>
    {/if}

    {#if vault.canSeeHistory}
      <section class="flex flex-col gap-3">
        <h2 class="text-base font-semibold">{t('ui.vault.history')}</h2>
        <div class="flex flex-col overflow-clip rounded-lg border border-border">
          <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
            <span class="w-27 shrink-0">{t('ui.vault.when')}</span>
            <span class="flex-1">{t('ui.vault.what')}</span>
            <span class="w-45 shrink-0">{t('ui.vault.who')}</span>
            <span class="w-25 shrink-0 text-right">{t('ui.common.amount')}</span>
          </div>
          {#each vault.history as entry (entry.id)}
            <div class="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0">
              <span class="w-27 shrink-0 text-13 text-muted-foreground tabular-nums">{stamp(entry.at, app.now)}</span>
              <span class="flex-1 truncate text-sm font-medium">{entry.what}</span>
              <span class="w-45 shrink-0 truncate text-13 text-muted-foreground">{entry.who}</span>
              <span class="w-25 shrink-0 text-right text-sm font-medium tabular-nums {entry.amount < 0 ? 'text-destructive' : 'text-success'}">{signedMoney(entry.amount)}</span>
            </div>
          {:else}
            <p class="px-4 py-8 text-center text-13 text-muted-foreground">{t('ui.vault.empty')}</p>
          {/each}
        </div>
      </section>
    {/if}
  </Main>

  <Side width="w-100" class="gap-0">
    <section class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.common.home_turf')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.vault.turf_hint')}</p>
      </div>
      <Select label={t('ui.common.home_turf')} icon={MapPin} placeholder={t('ui.common.pick_turf')} options={zones} bind:value={zone} disabled={!session.turf.canMove} onchange={() => turf.clear()} />
      <div class="flex items-center gap-3">
        <p class="flex-1 text-xs text-muted-foreground tabular-nums">
          {t('ui.vault.turf_cost', money(session.turf.cost))}
          {turfWait ? t('ui.vault.turf_wait', wait(turfWait, app.now)) : plural(session.turf.cooldownHours, 'ui.plural.turf_cooldown')}
        </p>
        {#if session.turf.canMove}
          <Button size="xs" disabled={!zone || zone === session.turf.zone || turfWait !== null || turf.busy} onclick={moveTurf}>{t('ui.vault.move_turf')}</Button>
        {/if}
      </div>
      <ErrorText error={turf.error} />
    </section>

    <section class="mt-6 flex flex-col gap-3 border-t border-border pt-6">
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.vault.hq')}</h2>
        <p class="text-13 text-muted-foreground">{session.hq.label ?? t('ui.vault.no_hq')}</p>
      </div>
      <div class="flex items-center gap-3">
        <p class="flex-1 text-xs text-muted-foreground tabular-nums">
          {#if session.hq.movedAt}{t('ui.vault.hq_moved', ago(session.hq.movedAt, app.now))}{/if}
          {hqWait ? t('ui.vault.hq_wait', wait(hqWait, app.now), money(session.hq.cost)) : t('ui.vault.hq_cost', money(session.hq.cost))}
        </p>
        {#if session.hq.canMove}
          <Button size="xs" disabled={hqWait !== null || hq.busy} onclick={() => hq.run(() => fetchNui('gang:pickHq'))}>{t('ui.vault.pick_spot')}</Button>
        {/if}
      </div>
      <ErrorText error={hq.error} />
    </section>
  </Side>
</Body>
