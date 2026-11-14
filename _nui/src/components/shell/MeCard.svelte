<script lang="ts">
  import type { Snippet } from 'svelte';
  import Avatar from '../ui/Avatar.svelte';

  let { name, detail, children }: { name: string; detail: string; children?: Snippet } = $props();
</script>

<div class="flex flex-col gap-2.5 rounded-lg border border-border bg-muted p-3">
  <div class="flex items-center gap-2.5">
    <Avatar {name} />
    <div class="flex min-w-0 flex-1 flex-col gap-0.5">
      <span class="truncate text-sm leading-[1.125rem] font-medium">{name}</span>
      <span class="truncate text-xs text-muted-foreground">{detail}</span>
    </div>
  </div>
  {#if children}{@render children()}{/if}
</div>
