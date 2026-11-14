<script lang="ts">
  import type { Snippet } from 'svelte';

  let { label, children }: { label: string; children: Snippet } = $props();
</script>

<div class="flex items-start justify-between gap-4 border-b border-border py-2.5 text-13">
  <span class="shrink-0 text-muted-foreground">{label}</span>
  <span class="min-w-0 text-right font-semibold tabular-nums">{@render children()}</span>
</div>
