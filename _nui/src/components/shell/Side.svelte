<script lang="ts">
  import type { Snippet } from 'svelte';

  let { width = 'w-95', class: className = 'gap-6', children }: { width?: string; class?: string; children: Snippet } = $props();
</script>

<aside class="flex shrink-0 flex-col overflow-y-auto border-l border-border px-6 pt-7 pb-6 {width} {className}">
  {@render children()}
</aside>
