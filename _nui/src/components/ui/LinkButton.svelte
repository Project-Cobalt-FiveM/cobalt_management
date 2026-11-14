<script lang="ts">
  import type { Snippet } from 'svelte';

  let { onclick, children }: { onclick: () => void; children: Snippet } = $props();
</script>

<button type="button" class="shrink-0 text-13 font-medium text-cobalt-foreground transition-colors hover:text-foreground" {onclick}>
  {@render children()}
</button>
