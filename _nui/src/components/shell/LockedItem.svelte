<script lang="ts">
  import Lock from 'phosphor-svelte/lib/Lock';

  let { label }: { label: string } = $props();
</script>

<div class="flex h-9 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-sm font-medium text-muted-foreground" aria-disabled="true">
  <span class="flex-1 truncate">{label}</span>
  <Lock size="0.75rem" class="text-muted-foreground" />
</div>
