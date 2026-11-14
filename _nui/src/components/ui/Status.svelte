<script lang="ts">
  type Tone = 'success' | 'warning' | 'danger' | 'muted';

  let { tone, label, inverted = false }: { tone: Tone; label: string; inverted?: boolean } = $props();

  const dots: Record<Tone, string> = {
    success: 'bg-success',
    warning: 'bg-warning',
    danger: 'bg-destructive',
    muted: 'bg-muted-foreground',
  };
</script>

<span class="inline-flex items-center gap-1.5 text-13 font-medium {tone === 'muted' && !inverted ? 'text-muted-foreground' : ''}">
  <span class="size-1.5 shrink-0 rounded-full {inverted ? 'bg-primary-foreground' : dots[tone]}"></span>
  {label}
</span>
