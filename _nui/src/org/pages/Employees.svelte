<script lang="ts">
  import UserPlus from 'phosphor-svelte/lib/UserPlus';
  import MagnifyingGlass from 'phosphor-svelte/lib/MagnifyingGlass';
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import Button from '../../components/ui/Button.svelte';
  import Badge from '../../components/ui/Badge.svelte';
  import Tabs from '../../components/ui/Tabs.svelte';
  import Status from '../../components/ui/Status.svelte';
  import EmployeeDetail from '../EmployeeDetail.svelte';
  import HireDialog from '../HireDialog.svelte';
  import FireDialog from '../FireDialog.svelte';
  import { hours, monthYear, money, plural } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import type { Employee, OrgSession } from '../../lib/types';
  import type { Tab } from '../../components/ui/types';

  type Filter = 'all' | 'duty' | 'leave';

  let { session }: { session: OrgSession } = $props();

  let filter = $state<Filter>('all');
  let query = $state('');
  let selectedId = $state<string | null>(null);
  let hiring = $state(false);
  let firing = $state<Employee | null>(null);

  const duty = $derived(session.features.duty);
  const employees = $derived(session.employees ?? []);
  const onDuty = $derived(employees.filter((employee) => employee.onDuty).length);
  const onLeave = $derived(employees.filter((employee) => employee.onLeave).length);

  const tabs = $derived<Tab<Filter>[]>([
    { value: 'all', label: t('ui.common.all'), count: employees.length },
    ...(duty ? [{ value: 'duty' as const, label: t('ui.common.on_duty'), count: onDuty }] : []),
    ...(session.features.leaves ? [{ value: 'leave' as const, label: t('ui.common.on_leave'), count: onLeave }] : []),
  ]);

  const shown = $derived(
    employees.filter((employee) => {
      if (filter === 'duty' && !employee.onDuty) return false;
      if (filter === 'leave' && !employee.onLeave) return false;

      const text = query.trim().toLowerCase();
      return text === '' || employee.name.toLowerCase().includes(text) || employee.citizenid.toLowerCase().includes(text);
    }),
  );

  const selected = $derived(
    employees.find((employee) => employee.citizenid === selectedId) ??
      employees.find((employee) => employee.citizenid !== session.me.citizenid) ??
      employees[0] ??
      null,
  );

  function status(employee: Employee): { tone: 'success' | 'warning' | 'muted'; label: string } {
    if (employee.onLeave) return { tone: 'warning', label: t('ui.common.on_leave') };
    if (duty && !employee.secondJob) return employee.onDuty ? { tone: 'success', label: t('ui.common.on_duty') } : { tone: 'muted', label: t('ui.common.off_duty') };
    return employee.online ? { tone: 'success', label: t('ui.common.in_the_city') } : { tone: 'muted', label: t('ui.common.away') };
  }
</script>

<TopBar
  title={t('ui.page.employees')}
  subtitle={duty ? t('ui.employees.subtitle_duty', plural(employees.length, 'ui.plural.person'), onDuty) : plural(employees.length, 'ui.plural.person')}
>
  {#snippet actions()}
    {#if session.access.manageStaff}
      <Button variant="primary" onclick={() => (hiring = true)}><UserPlus size="1rem" />{t('ui.hire.hire')}</Button>
    {/if}
  {/snippet}
</TopBar>

<Body>
  <Main class="gap-4 px-6">
    <div class="flex items-center gap-4">
      <div class="flex-1"><Tabs {tabs} bind:value={filter} /></div>
      <label class="flex h-8 w-70 items-center gap-2 rounded-md border border-input px-3 transition-colors focus-within:border-primary">
        <MagnifyingGlass size="0.875rem" class="shrink-0 text-muted-foreground" />
        <input class="h-full min-w-0 flex-1 bg-transparent text-13 outline-none" placeholder={t('ui.employees.search')} aria-label={t('ui.employees.search_aria')} bind:value={query} />
      </label>
    </div>

    <div class="flex flex-col overflow-clip rounded-lg border border-border">
      <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
        <span class="flex-1">{t('ui.common.employee')}</span>
        <span class="w-40 shrink-0">{t('ui.common.rank')}</span>
        <span class="w-20 shrink-0 text-right">{t('ui.common.pay')}</span>
        {#if duty}<span class="w-20 shrink-0 text-right">{t('ui.common.this_week')}</span>{/if}
        <span class="w-24 shrink-0 pl-3">{t('ui.common.status')}</span>
      </div>
      {#each shown as employee (employee.citizenid)}
        {@const active = selected?.citizenid === employee.citizenid}
        {@const state = status(employee)}
        <button
          type="button"
          aria-pressed={active}
          class="flex items-center gap-4 border-b border-border px-4 py-3 text-left transition-colors last:border-b-0 {active ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'}"
          onclick={() => (selectedId = employee.citizenid)}
        >
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="flex min-w-0 items-center gap-2">
              <span class="truncate text-sm font-medium">{employee.name}</span>
              {#if employee.secondJob}<Badge tone={active ? 'onPrimary' : 'neutral'}>{t('ui.jobs.second')}</Badge>{/if}
            </span>
            <span class="truncate text-xs tabular-nums {active ? 'text-primary-foreground' : 'text-muted-foreground'}">
              {employee.joinedAt ? t('ui.employee.id_joined', employee.citizenid, monthYear(employee.joinedAt)) : employee.citizenid}
            </span>
          </span>
          <span class="w-40 shrink-0 truncate text-13 font-medium">{employee.rank}</span>
          <span class="w-20 shrink-0 text-right text-13 font-medium tabular-nums">{money(employee.pay)}</span>
          {#if duty}<span class="w-20 shrink-0 text-right text-13 font-medium tabular-nums">{hours(employee.weekMinutes)}</span>{/if}
          <span class="w-24 shrink-0 pl-3"><Status tone={state.tone} label={state.label} inverted={active} /></span>
        </button>
      {:else}
        <p class="px-4 py-8 text-center text-13 text-muted-foreground">{t('ui.employees.no_match')}</p>
      {/each}
    </div>
  </Main>

  {#if selected}
    <Side class="gap-0">
      {#key selected.citizenid}
        <EmployeeDetail {session} employee={selected} onfire={() => (firing = selected)} />
      {/key}
    </Side>
  {/if}
</Body>

{#if hiring}
  <HireDialog {session} onclose={() => (hiring = false)} />
{/if}

{#if firing}
  <FireDialog {session} employee={firing} onclose={() => (firing = null)} />
{/if}
