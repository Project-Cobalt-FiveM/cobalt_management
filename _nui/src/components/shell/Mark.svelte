<script lang="ts">
  import type { Icon } from '../ui/types';

  let { icon: Glyph, logo = null }: { icon: Icon; logo?: string | null } = $props();

  let broken = $state(false);

  $effect(() => {
    if (logo) broken = false;
  });
</script>

<div class="flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-md bg-secondary">
  {#if logo && !broken}
    <img src={logo} alt="" class="size-full object-cover" onerror={() => (broken = true)} />
  {:else}
    <Glyph size="1.25rem" class="text-foreground" />
  {/if}
</div>
