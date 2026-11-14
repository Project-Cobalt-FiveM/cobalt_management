<script lang="ts" generics="T extends string">
  import type { Tab } from './types';

  let { tabs, value = $bindable(), fill = false, onchange }: { tabs: Tab<T>[]; value: T; fill?: boolean; onchange?: (value: T) => void } = $props();

  function select(next: T) {
    if (next === value) return;

    value = next;
    onchange?.(next);
  }
</script>

<div class="flex gap-1 rounded-lg border border-border bg-muted p-1 {fill ? 'w-full' : 'w-fit'}" role="tablist">
  {#each tabs as tab (tab.value)}
    {@const active = tab.value === value}
    <button
      type="button"
      role="tab"
      aria-selected={active}
      class="h-8 rounded-md text-sm font-medium transition-colors {fill ? 'flex-1' : 'px-8'} {active
        ? 'bg-primary text-primary-foreground'
        : 'text-muted-foreground hover:text-foreground'}"
      onclick={() => select(tab.value)}
    >
      {tab.label}
    </button>
  {/each}
</div>
