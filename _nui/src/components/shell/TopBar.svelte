<script lang="ts">
  import type { Snippet } from 'svelte';
  import CloseHint from './CloseHint.svelte';

  let { title, subtitle, actions }: { title: string; subtitle: string; actions?: Snippet } = $props();
</script>

<header class="flex h-18 shrink-0 items-center gap-4 border-b border-border px-6">
  <div class="flex min-w-0 flex-1 flex-col gap-0.5">
    <h1 class="truncate text-xl leading-7 font-semibold tracking-[-0.01em]">{title}</h1>
    <p class="truncate text-13 text-muted-foreground">{subtitle}</p>
  </div>
  {#if actions}<div class="flex shrink-0 items-center gap-2">{@render actions()}</div>{/if}
  <CloseHint />
</header>

