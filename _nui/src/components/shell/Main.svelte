<script lang="ts">
  import type { Snippet } from 'svelte';

  let { class: className = 'gap-7 px-6', children }: { class?: string; children: Snippet } = $props();
</script>

<div class="flex min-w-0 flex-1 flex-col overflow-y-auto pt-7 pb-6 {className}">
  {@render children()}
</div>
