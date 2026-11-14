<script lang="ts">
  type Props = { value: number | null; label: string; placeholder?: string; size?: 'md' | 'lg'; disabled?: boolean; class?: string; oninput?: () => void };

  let { value = $bindable(), label, placeholder = '0', size = 'md', disabled = false, class: className = '', oninput }: Props = $props();

  const text = $derived(value === null ? '' : value.toLocaleString('en-US'));

  function read(event: Event & { currentTarget: HTMLInputElement }) {
    const digits = event.currentTarget.value.replace(/\D/g, '').slice(0, 10);
    value = digits === '' ? null : Number(digits);
    event.currentTarget.value = value === null ? '' : value.toLocaleString('en-US');
    oninput?.();
  }
</script>

<div
  class="flex items-center gap-1.5 rounded-md border border-input px-3 transition-colors focus-within:border-primary {size === 'lg'
    ? 'h-12 text-xl font-semibold'
    : 'h-9 text-sm'} {className}"
>
  <span class="text-muted-foreground {size === 'lg' ? 'font-normal' : ''}">$</span>
  <input
    class="h-full min-w-0 flex-1 bg-transparent tabular-nums outline-none"
    inputmode="numeric"
    aria-label={label}
    {placeholder}
    {disabled}
    value={text}
    oninput={read}
  />
</div>
