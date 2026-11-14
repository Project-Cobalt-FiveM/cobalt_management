<script lang="ts">
  import { initials } from '../../lib/format';

  let { name, size = 'md', inverted = false }: { name: string; size?: 'md' | 'lg'; inverted?: boolean } = $props();
</script>

<span
  class="flex shrink-0 items-center justify-center rounded-full font-semibold {size === 'lg' ? 'size-12 text-base' : 'size-8 text-xs'} {inverted
    ? 'bg-foreground text-primary'
    : 'bg-secondary text-foreground'}"
  aria-hidden="true"
>
  {initials(name)}
</span>
