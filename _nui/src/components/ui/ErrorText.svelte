<script lang="ts">
  let { error, class: className = '' }: { error: string | null; class?: string } = $props();
</script>

{#if error}
  <p class="text-xs text-destructive {className}" role="alert">{error}</p>
{/if}
