<script lang="ts">
  import Check from 'phosphor-svelte/lib/Check';

  let { checked, disabled = false, label, onchange }: { checked: boolean; disabled?: boolean; label: string; onchange: (checked: boolean) => void } = $props();

  const fill = $derived(checked ? (disabled ? 'bg-control' : 'bg-primary') : 'border-[1.5px] border-control');
</script>

<button
  type="button"
  role="checkbox"
  aria-checked={checked}
  aria-label={label}
  {disabled}
  class="flex size-4.5 shrink-0 items-center justify-center rounded-sm transition-colors disabled:cursor-default {fill}"
  onclick={() => onchange(!checked)}
>
  {#if checked}<Check size="0.6875rem" class="text-primary-foreground" />{/if}
</button>
