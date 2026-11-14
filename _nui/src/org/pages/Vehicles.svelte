<script lang="ts">
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import Button from '../../components/ui/Button.svelte';
  import ErrorText from '../../components/ui/ErrorText.svelte';
  import Emphasis from '../../components/ui/Emphasis.svelte';
  import { Action, app } from '../../lib/store.svelte';
  import { fetchNui } from '../../lib/nui';
  import { ago, money, plural } from '../../lib/format';
  import { parts, t } from '../../lib/locale.svelte';
  import type { CatalogueVehicle, OrgSession } from '../../lib/types';

  let { session }: { session: OrgSession } = $props();

  const buy = new Action();

  let buying = $state<string | null>(null);

  const vehicles = $derived(session.vehicles);
  const balance = $derived(session.society?.balance ?? 0);

  function drivers(vehicle: CatalogueVehicle): string {
    return vehicle.minGrade <= 0 ? t('ui.vehicles.everyone') : t('ui.vehicles.and_up', vehicle.minRank);
  }

  async function purchase(vehicle: CatalogueVehicle) {
    buying = vehicle.model;
    await buy.run(() => fetchNui('buyVehicle', { model: vehicle.model }));
    buying = null;
  }
</script>

<TopBar title={t('ui.page.vehicles')} subtitle={t('ui.vehicles.subtitle')} />

{#if vehicles}
  <Body>
    <Main class="gap-4 px-6">
      <div class="flex items-center gap-4">
        <h2 class="flex-1 text-base font-semibold">{t('ui.vehicles.available')}</h2>
        <span class="text-13 text-muted-foreground">
          <Emphasis parts={parts('ui.vehicles.balance', money(balance))} class="font-semibold text-foreground tabular-nums" />
        </span>
      </div>

      <div class="flex flex-col overflow-clip rounded-lg border border-border">
        <div class="flex items-center gap-4 border-b border-border bg-muted px-4 py-2.5 text-xs font-medium text-muted-foreground">
          <span class="flex-1">{t('ui.vehicles.vehicle')}</span>
          <span class="w-30 shrink-0">{t('ui.vehicles.use')}</span>
          <span class="w-45 shrink-0">{t('ui.vehicles.drivers')}</span>
          <span class="w-25 shrink-0 text-right">{t('ui.vehicles.price')}</span>
          <span class="w-28 shrink-0"></span>
        </div>
        {#each vehicles.catalogue as vehicle (vehicle.model)}
          {@const short = vehicle.price - balance}
          <div class="flex min-h-14 items-center gap-4 border-b border-border px-4 py-2.5 last:border-b-0">
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="truncate text-sm font-semibold">{vehicle.label}</span>
              {#if short > 0}<span class="truncate text-xs text-muted-foreground tabular-nums">{t('ui.vehicles.needs', money(short))}</span>{/if}
            </span>
            <span class="w-30 shrink-0 truncate text-13 text-muted-foreground">{vehicle.use}</span>
            <span class="w-45 shrink-0 truncate text-13 font-medium">{drivers(vehicle)}</span>
            <span class="w-25 shrink-0 text-right text-sm font-semibold tabular-nums">{vehicle.price > 0 ? money(vehicle.price) : t('ui.vehicles.free')}</span>
            <span class="flex w-28 shrink-0 justify-end">
              <Button size="xs" disabled={short > 0 || buy.busy} onclick={() => purchase(vehicle)}>
                {buying === vehicle.model ? t('ui.vehicles.buying') : vehicle.price > 0 ? t('ui.vehicles.buy') : t('ui.vehicles.add')}
              </Button>
            </span>
          </div>
        {:else}
          <p class="px-4 py-8 text-center text-13 text-muted-foreground">{t('ui.vehicles.none')}</p>
        {/each}
      </div>
      <ErrorText error={buy.error} />
      <p class="text-xs text-muted-foreground">{t('ui.vehicles.garage_note')}</p>
    </Main>

    <Side>
      <section class="flex flex-col gap-3">
        <div class="flex items-center gap-4">
          <h2 class="flex-1 text-base font-semibold">{t('ui.vehicles.fleet')}</h2>
          <span class="text-13 text-muted-foreground tabular-nums">{plural(vehicles.fleet.length, 'ui.plural.vehicle')}</span>
        </div>
        <div class="flex flex-col">
          {#each vehicles.fleet as vehicle (vehicle.plate)}
            <div class="flex items-center gap-3 border-b border-border py-3 last:border-b-0">
              <span class="flex h-6 w-19 shrink-0 items-center justify-center rounded-sm bg-foreground text-xs font-bold tracking-wide text-background tabular-nums">{vehicle.plate}</span>
              <span class="flex min-w-0 flex-col gap-0.5">
                <span class="truncate text-sm font-semibold">{vehicle.label}</span>
                <span class="truncate text-xs text-muted-foreground">{t('ui.common.by_on', vehicle.boughtBy, ago(vehicle.boughtAt, app.now))}</span>
              </span>
            </div>
          {:else}
            <p class="text-13 text-muted-foreground">{t('ui.vehicles.no_fleet')}</p>
          {/each}
        </div>
      </section>
    </Side>
  </Body>
{/if}
