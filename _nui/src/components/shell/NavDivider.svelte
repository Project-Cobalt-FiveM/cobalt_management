<script lang="ts">
  let { class: className = '' }: { class?: string } = $props();
</script>

<div class="px-2.5 py-1.5 {className}"><div class="h-px bg-border"></div></div>
