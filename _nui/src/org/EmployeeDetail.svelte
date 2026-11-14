<script lang="ts">
  import CaretDown from 'phosphor-svelte/lib/CaretDown';
  import CaretUp from 'phosphor-svelte/lib/CaretUp';
  import Gift from 'phosphor-svelte/lib/Gift';
  import UserMinus from 'phosphor-svelte/lib/UserMinus';
  import Button from '../components/ui/Button.svelte';
  import Row from '../components/ui/Row.svelte';
  import MoneyInput from '../components/ui/MoneyInput.svelte';
  import ErrorText from '../components/ui/ErrorText.svelte';
  import { Action } from '../lib/store.svelte';
  import { fetchNui } from '../lib/nui';
  import { firstName, hours, longDate, money } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Employee, OrgSession, Rank } from '../lib/types';

  let { session, employee, onfire }: { session: OrgSession; employee: Employee; onfire: () => void } = $props();

  const grade = new Action();
  const bonus = new Action();

  let amount = $state<number | null>(500);
  let reason = $state('');

  const isSelf = $derived(employee.citizenid === session.me.citizenid);
  const ranks = $derived([...session.ranks].sort((a, b) => a.grade - b.grade));
  const lower = $derived(ranks.filter((rank) => rank.grade < employee.grade).at(-1) ?? null);
  const higher = $derived(ranks.find((rank) => rank.grade > employee.grade) ?? null);
  const canManage = $derived(session.access.manageStaff && !isSelf && (session.me.isBoss || employee.grade < session.me.grade));
  const canPromote = $derived(canManage && higher !== null && (session.me.isBoss || higher.grade < session.me.grade));
  const canBonus = $derived(session.access.bonus && !isSelf && session.features.society);
  const bonusValid = $derived(amount !== null && amount > 0 && amount <= session.limits.bonus);
  const name = $derived(firstName(employee.name));

  const rankHint = $derived(
    [
      higher && canPromote ? t('ui.employee.promote_hint', higher.name, money(higher.pay)) : null,
      lower && canManage ? t('ui.employee.demote_hint', lower.name, money(lower.pay)) : null,
    ]
      .filter(Boolean)
      .join(' '),
  );

  function move(rank: Rank | null) {
    if (!rank) return;
    void grade.run(() => fetchNui('setGrade', { citizenid: employee.citizenid, grade: rank.grade }));
  }

  async function give() {
    if (amount === null || !bonusValid) return;

    const value = amount;
    const sent = await bonus.run(() => fetchNui('giveBonus', { citizenid: employee.citizenid, amount: value, reason: reason.trim() }));
    if (sent) reason = '';
  }
</script>

<div class="flex flex-col gap-1">
  <span class="text-13 text-muted-foreground tabular-nums">
    {employee.joinedAt ? t('ui.employee.id_joined', employee.citizenid, longDate(employee.joinedAt)) : employee.citizenid}
  </span>
  <h2 class="text-xl leading-7 font-semibold tracking-[-0.01em]">{employee.name}</h2>
</div>

<div class="mt-6 flex flex-col gap-2">
  <span class="text-sm font-semibold">{t('ui.common.rank')}</span>
  <div class="flex gap-2">
    <div class="flex h-9 min-w-0 flex-1 items-center gap-2 rounded-md border border-input px-3 text-sm">
      <span class="flex-1 truncate font-medium">{employee.rank}</span>
      <span class="text-13 text-muted-foreground tabular-nums">{t('ui.common.grade', employee.grade)}</span>
    </div>
    {#if canManage}
      <Button size="icon" class="size-9" aria-label={lower ? t('ui.employee.demote_to', lower.name) : t('ui.employee.demote')} disabled={!lower || grade.busy} onclick={() => move(lower)}>
        <CaretDown size="0.875rem" />
      </Button>
      <Button size="icon" class="size-9" aria-label={higher ? t('ui.employee.promote_to', higher.name) : t('ui.employee.promote')} disabled={!canPromote || grade.busy} onclick={() => move(higher)}>
        <CaretUp size="0.875rem" />
      </Button>
    {/if}
  </div>
  {#if rankHint}<p class="text-xs text-muted-foreground">{rankHint}</p>{/if}
  <ErrorText error={grade.error} />
</div>

<div class="mt-4 flex flex-col">
  {#if employee.secondJob}
    <Row label={t('ui.jobs.job')}>{t('ui.jobs.second')}</Row>
  {:else if session.features.duty}
    <Row label={t('ui.common.hours_this_week')}>{hours(employee.weekMinutes)}</Row>
    <Row label={t('ui.employee.hours_last_week')}>{hours(employee.lastWeekMinutes)}</Row>
  {/if}
  <Row label={t('ui.common.pay_per_payday')}>{money(employee.pay)}</Row>
  <Row label={t('ui.common.bonuses_this_month')}>{money(employee.monthBonuses)}</Row>
</div>

{#if canBonus}
  <div class="mt-6 flex flex-col gap-2">
    <span class="text-sm font-semibold">{t('ui.employee.give_bonus')}</span>
    <div class="flex gap-2">
      <MoneyInput class="w-30 shrink-0" label={t('ui.employee.bonus_amount')} bind:value={amount} oninput={() => bonus.clear()} />
      <input
        class="field min-w-0 flex-1"
        placeholder={t('ui.employee.reason_optional')}
        aria-label={t('ui.employee.bonus_reason')}
        maxlength={session.limits.reason}
        bind:value={reason}
      />
    </div>
    <Button class="w-full" disabled={!bonusValid || bonus.busy} onclick={give}>
      <Gift size="1rem" />{amount ? t('ui.employee.give_amount', money(amount)) : t('ui.employee.give_bonus')}
    </Button>
    <p class="text-xs text-muted-foreground">
      {amount !== null && amount > session.limits.bonus ? t('ui.employee.bonus_cap', money(session.limits.bonus)) : t('ui.employee.bonus_paid', name)}
    </p>
    <ErrorText error={bonus.error} />
  </div>
{/if}

{#if canManage}
  <div class="mt-auto pt-6">
    <Button variant="destructive" class="w-full" onclick={onfire}><UserMinus size="1rem" />{t('ui.employee.fire', name)}</Button>
  </div>
{/if}
