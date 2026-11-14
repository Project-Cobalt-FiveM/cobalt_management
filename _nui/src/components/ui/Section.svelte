<script lang="ts">
  import type { Snippet } from 'svelte';

  type Props = { title: string; description?: string; aside?: Snippet; class?: string; children?: Snippet };

  let { title, description, aside, class: className = '', children }: Props = $props();
</script>

<section class="flex flex-col gap-3 {className}">
  <div class="flex items-center gap-4">
    <div class="flex min-w-0 flex-1 flex-col gap-1">
      <h2 class="text-base font-semibold">{title}</h2>
      {#if description}<p class="text-13 text-muted-foreground">{description}</p>{/if}
    </div>
    {#if aside}{@render aside()}{/if}
  </div>
  {#if children}{@render children()}{/if}
</section>
