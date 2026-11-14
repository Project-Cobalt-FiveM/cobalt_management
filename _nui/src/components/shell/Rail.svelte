<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { Icon } from '../ui/types';
  import Mark from './Mark.svelte';

  type Props = { title: string; subtitle: string; icon: Icon; logo?: string | null; children: Snippet; footer: Snippet };

  let { title, subtitle, icon, logo = null, children, footer }: Props = $props();
</script>

<aside class="flex w-60 shrink-0 flex-col gap-4 border-r border-border bg-card px-3 pb-4">
  <div class="-mx-3 flex h-18 shrink-0 items-center gap-3 border-b border-border px-2">
    <Mark {icon} {logo} />
    <div class="flex min-w-0 flex-col gap-0.5">
      <span class="truncate text-15 font-semibold">{title}</span>
      <span class="truncate text-xs text-muted-foreground">{subtitle}</span>
    </div>
  </div>

  <nav class="flex min-h-0 flex-1 flex-col gap-0.5 overflow-y-auto">
    {@render children()}
  </nav>

  {@render footer()}
</aside>
