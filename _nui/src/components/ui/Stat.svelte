<script lang="ts">
  import type { Snippet } from 'svelte';

  let { label, size = 'lg', children }: { label: string; size?: 'md' | 'lg'; children: Snippet } = $props();
</script>

<div class="flex min-w-0 flex-1 flex-col gap-1 py-4">
  <span class="text-xs text-muted-foreground">{label}</span>
  <span class="truncate font-semibold tabular-nums {size === 'lg' ? 'text-xl leading-7' : 'text-sm'}">{@render children()}</span>
</div>
