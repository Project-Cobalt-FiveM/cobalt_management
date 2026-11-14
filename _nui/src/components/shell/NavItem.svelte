<script lang="ts">
  import type { Icon } from '../ui/types';

  type Props = { label: string; icon: Icon; active?: boolean; count?: number; badge?: number; onclick: () => void };

  let { label, icon: Glyph, active = false, count, badge, onclick }: Props = $props();
</script>

<button
  type="button"
  aria-current={active ? 'page' : undefined}
  class="flex h-9 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-left text-sm font-medium transition-colors {active ? 'bg-primary text-primary-foreground' : 'hover:bg-muted'}"
  {onclick}
>
  <Glyph size="1rem" class={active ? 'text-primary-foreground' : 'text-muted-foreground'} />
  <span class="flex-1 truncate">{label}</span>
  {#if badge}
    <span class="rounded-sm px-1.5 py-px text-xs font-semibold tabular-nums {active ? 'bg-foreground text-primary' : 'bg-secondary'}">{badge}</span>
  {:else if count !== undefined}
    <span class="text-xs tabular-nums {active ? 'text-primary-foreground' : 'text-muted-foreground'}">{count}</span>
  {/if}
</button>

