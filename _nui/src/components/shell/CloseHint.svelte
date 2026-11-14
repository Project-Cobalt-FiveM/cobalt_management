<script lang="ts">
  import { app } from '../../lib/store.svelte';
  import { t } from '../../lib/locale.svelte';
</script>

<button type="button" class="flex shrink-0 items-center gap-1.5 rounded-sm text-xs text-muted-foreground transition-colors hover:text-foreground" onclick={() => app.close()}>
  <span class="kbd leading-[1.125rem] font-medium">{t('ui.common.esc')}</span>
  {t('ui.common.close')}
</button>
