<script lang="ts">
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Button from '../../components/ui/Button.svelte';
  import Tabs from '../../components/ui/Tabs.svelte';
  import Segmented from '../../components/ui/Segmented.svelte';
  import MoneyInput from '../../components/ui/MoneyInput.svelte';
  import ErrorText from '../../components/ui/ErrorText.svelte';
  import Emphasis from '../../components/ui/Emphasis.svelte';
  import WithdrawDialog from '../WithdrawDialog.svelte';
  import { Action, app, type FundsMode } from '../../lib/store.svelte';
  import { fetchNui } from '../../lib/nui';
  import { money, plural, signedMoney, stamp, wait } from '../../lib/format';
  import { parts, t } from '../../lib/locale.svelte';
  import type { JobSession } from '../../lib/types';
  import type { Tab } from '../../components/ui/types';

  type Flow = 'all' | 'in' | 'out';

  let { session }: { session: JobSession } = $props();

  const move = new Action();

  let amount = $state<number | null>(null);
  let note = $state('');
  let flow = $state<Flow>('all');
  let confirming = $state(false);

  const modes: Tab<FundsMode>[] = $derived([
    { value: 'deposit', label: t('ui.common.deposit') },
    { value: 'withdraw', label: t('ui.common.withdraw') },
  ]);

  const flows: Tab<Flow>[] = $derived([
    { value: 'all', label: t('ui.common.all') },
    { value: 'in', label: t('ui.society.money_in') },
    { value: 'out', label: t('ui.society.money_out') },
  ]);

  const quick = [1000, 5000, 25000];

  const society = $derived(session.society);
  const withdrawing = $derived(app.fundsMode === 'withdraw');
  const tooMuch = $derived(withdrawing && society !== null && amount !== null && amount > society.balance);
  const valid = $derived(amount !== null && amount > 0 && !tooMuch);
  const action = $derived.by(() => {
    if (!amount) return withdrawing ? t('ui.common.withdraw') : t('ui.common.deposit');
    return withdrawing ? t('ui.society.withdraw_amount', money(amount)) : t('ui.society.deposit_amount', money(amount));
  });
  const transactions = $derived(
    (society?.transactions ?? []).filter((entry) => flow === 'all' || (flow === 'in' ? entry.amount > 0 : entry.amount < 0)),
  );

  async function deposit() {
    if (amount === null) return;

    const value = amount;
    if (await move.run(() => fetchNui('deposit', { amount: value, note: note.trim() }))) reset();
  }

  function submit() {
    if (!valid) return;
    if (withdrawing) confirming = true;
    else void deposit();
  }

  function reset() {
    amount = null;
    note = '';
  }
</script>

<TopBar title={t('ui.page.society')} subtitle={society ? t('ui.society.subtitle', society.accountId) : t('ui.overview.society_account')} />

{#if society}
  <Body>
    <div class="flex w-105 shrink-0 flex-col gap-6 border-r border-border px-6 pt-7 pb-6">
      <div class="flex flex-col gap-1.5">
        <span class="text-13 font-medium text-muted-foreground">{t('ui.society.balance')}</span>
        <span class="text-[2.75rem] leading-12 font-semibold tracking-[-0.02em] tabular-nums">{money(society.balance)}</span>
        <p class="text-sm text-muted-foreground">
          <Emphasis parts={parts('ui.society.next_payday', wait(society.nextPaydayAt, app.now), money(society.payroll))} />
        </p>
      </div>

      <div class="flex flex-col gap-4">
        <Segmented tabs={modes} bind:value={app.fundsMode} fill onchange={() => move.clear()} />

        <div class="flex flex-col gap-2">
          <span class="text-sm font-semibold">{t('ui.common.amount')}</span>
          <MoneyInput size="lg" label={t('ui.common.amount')} bind:value={amount} oninput={() => move.clear()} />
          <div class="grid gap-1.5 {withdrawing ? 'grid-cols-4' : 'grid-cols-3'}">
            {#each quick as value (value)}
              <Button size="sm" class="font-semibold tabular-nums" onclick={() => (amount = value)}>{money(value)}</Button>
            {/each}
            {#if withdrawing}
              <Button size="sm" class="font-semibold" onclick={() => (amount = society.balance)}>{t('ui.common.all')}</Button>
            {/if}
          </div>
        </div>

        <label class="flex flex-col gap-2">
          <span class="text-sm font-semibold">{t('ui.society.note')}</span>
          <input class="field" placeholder={t('ui.society.note_placeholder')} maxlength={120} bind:value={note} />
        </label>

        <Button variant="primary" size="lg" class="w-full" disabled={!valid || move.busy} onclick={submit}>{action}</Button>
        <p class="text-xs text-muted-foreground">
          {#if tooMuch}
            {t('ui.society.holds', money(society.balance))}
          {:else if withdrawing}
            {t('ui.society.withdraw_hint')}
          {:else}
            {t('ui.society.deposit_hint')}
          {/if}
        </p>
        <ErrorText error={move.error} />
      </div>
    </div>

    <Main class="gap-4 px-6">
      <div class="flex items-center gap-4">
        <h2 class="flex-1 text-base font-semibold">{t('ui.society.transactions')}</h2>
        <Tabs tabs={flows} bind:value={flow} />
      </div>

      <div class="flex flex-col overflow-clip rounded-lg border border-border">
        <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
          <span class="w-27 shrink-0">{t('ui.society.date')}</span>
          <span class="flex-1">{t('ui.society.description')}</span>
          <span class="w-50 shrink-0">{t('ui.society.by')}</span>
          <span class="w-25 shrink-0 text-right">{t('ui.common.amount')}</span>
        </div>
        {#each transactions as entry (entry.id)}
          <div class="flex items-center gap-4 border-b border-border px-4 py-3 last:border-b-0">
            <span class="w-27 shrink-0 text-13 text-muted-foreground tabular-nums">{stamp(entry.at, app.now)}</span>
            <span class="flex-1 truncate text-sm font-medium">{entry.description}</span>
            <span class="w-50 shrink-0 truncate text-13 text-muted-foreground">{entry.by}</span>
            <span class="w-25 shrink-0 text-right text-sm font-medium tabular-nums {entry.amount < 0 ? 'text-destructive' : 'text-success'}">{signedMoney(entry.amount)}</span>
          </div>
        {:else}
          <p class="px-4 py-8 text-center text-13 text-muted-foreground">{t('ui.society.empty')}</p>
        {/each}
      </div>
      {#if society.transactions.length > 0}
        <p class="text-xs text-muted-foreground">{t('ui.society.latest', plural(society.transactions.length, 'ui.plural.transaction'))}</p>
      {/if}
    </Main>
  </Body>

  {#if confirming && amount !== null}
    <WithdrawDialog {session} {society} {amount} {note} onclose={() => (confirming = false)} ondone={reset} />
  {/if}
{/if}
