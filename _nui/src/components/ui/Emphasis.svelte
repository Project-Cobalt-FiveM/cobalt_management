<script lang="ts">
  import type { Part } from '../../lib/locale.svelte';

  let { parts, class: className = 'text-foreground tabular-nums' }: { parts: Part[]; class?: string } = $props();
</script>

{#each parts as part, index (index)}{#if part.value}<span class={className}>{part.text}</span>{:else}{part.text}{/if}{/each}
