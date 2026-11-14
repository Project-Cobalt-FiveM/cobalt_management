<script lang="ts">
  type Props = { checked: boolean; disabled?: boolean; size?: 'sm' | 'md'; label: string; onchange: (checked: boolean) => void };

  let { checked, disabled = false, size = 'md', label, onchange }: Props = $props();
</script>

<button
  type="button"
  role="switch"
  aria-checked={checked}
  aria-label={label}
  {disabled}
  class="relative inline-flex shrink-0 items-center rounded-full p-0.5 transition-colors disabled:cursor-default {size === 'sm' ? 'h-4.5 w-8' : 'h-5 w-9'} {checked
    ? 'bg-primary'
    : 'bg-secondary'}"
  onclick={() => onchange(!checked)}
>
  <span
    class="rounded-full transition-transform {size === 'sm' ? 'size-3.5' : 'size-4'} {checked
      ? `bg-foreground ${size === 'sm' ? 'translate-x-3.5' : 'translate-x-4'}`
      : 'bg-muted-foreground'}"
  ></span>
</button>
