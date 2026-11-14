<script lang="ts">
  import type { Snippet } from 'svelte';

  let { children }: { children: Snippet } = $props();
</script>

<div class="flex border-y border-border [&>*+*]:border-l [&>*+*]:border-border [&>*+*]:pl-5">
  {@render children()}
</div>
