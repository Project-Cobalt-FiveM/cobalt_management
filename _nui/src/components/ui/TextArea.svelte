<script lang="ts">
  type Props = { value: string; label: string; placeholder?: string; max: number; rows?: string; hint?: string; focus?: boolean };

  let { value = $bindable(), label, placeholder, max, rows = 'h-40', hint, focus = false }: Props = $props();

  function autofocus(node: HTMLTextAreaElement) {
    if (focus) node.focus();
  }
</script>

<div class="flex flex-col gap-2">
  <textarea
    use:autofocus
    class="field resize-none py-2.5 leading-[1.375rem] {rows}"
    aria-label={label}
    {placeholder}
    maxlength={max}
    bind:value
  ></textarea>
  <div class="flex justify-between gap-4 text-xs text-muted-foreground">
    <span>{hint ?? ''}</span>
    <span class="tabular-nums">{value.length} / {max}</span>
  </div>
</div>
