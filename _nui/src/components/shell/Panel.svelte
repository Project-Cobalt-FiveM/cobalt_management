<script lang="ts">
  import type { Snippet } from 'svelte';
  import { rise } from '../../lib/motion';

  let { rail, children }: { rail: Snippet; children: Snippet } = $props();
</script>

<div class="fixed inset-0 flex items-center justify-center">
  <div class="relative flex h-[57.5rem] w-[102.5rem] overflow-hidden rounded-lg border border-border bg-card" transition:rise={{ duration: 300 }}>
    {@render rail()}
    <main class="relative flex min-w-0 flex-1 flex-col">
      {@render children()}
    </main>
  </div>
</div>
