<script lang="ts">
  import type { Snippet } from 'svelte';
  import { crossfade } from '../../lib/motion';

  let { children }: { children: Snippet } = $props();
</script>

<div class="flex min-h-0 flex-1" in:crossfade>
  {@render children()}
</div>
