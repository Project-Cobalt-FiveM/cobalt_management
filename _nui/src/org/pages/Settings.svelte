<script lang="ts">
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Button from '../../components/ui/Button.svelte';
  import Toggle from '../../components/ui/Toggle.svelte';
  import ErrorText from '../../components/ui/ErrorText.svelte';
  import { Action } from '../../lib/store.svelte';
  import { fetchNui } from '../../lib/nui';
  import { featureText, features, orgIcon } from '../meta';
  import { t } from '../../lib/locale.svelte';
  import type { OrgFeature, OrgSession } from '../../lib/types';

  let { session }: { session: OrgSession } = $props();

  const logo = new Action();
  const feature = new Action();

  let url = $state('');
  let broken = $state(false);

  const storedLogo = $derived(session.org.logoUrl ?? '');

  $effect.pre(() => {
    url = storedLogo;
  });

  const Glyph = $derived(orgIcon(session.org.type));
  const hosts = $derived(session.logoHosts);
  const hostList = $derived(hosts.join(', '));
  const logosOn = $derived(hosts.length > 0);
  const allowed = $derived(url.trim() === '' || hostAllowed(url.trim()));
  const unchanged = $derived(url.trim() === storedLogo);

  function hostAllowed(link: string): boolean {
    const host = /^https:\/\/([A-Za-z0-9.-]+)([/?#].*)?$/.exec(link)?.[1];
    return host !== undefined && hosts.includes(host.toLowerCase());
  }

  function toggle(name: OrgFeature, enabled: boolean) {
    void feature.run(() => fetchNui('setFeature', { feature: name, enabled }));
  }

  function saveLogo() {
    if (!allowed) return;

    broken = false;
    void logo.run(() => fetchNui('saveLogo', { url: url.trim() }));
  }
</script>

<TopBar title={t('ui.page.settings')} subtitle={t('ui.settings.subtitle', session.org.label)} />

<Body>
  <Main class="flex-row items-start gap-12 px-12">
    <section class="flex w-90 shrink-0 flex-col gap-4">
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.settings.logo')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.settings.logo_body', session.org.label)}</p>
      </div>

      <div class="flex items-center gap-4">
        <div class="flex size-18 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-border bg-secondary">
          {#if session.org.logoUrl && !broken}
            <img src={session.org.logoUrl} alt="" class="size-full object-cover" onerror={() => (broken = true)} />
          {:else}
            <Glyph size="1.75rem" class="text-foreground" />
          {/if}
        </div>
        <p class="text-13 text-muted-foreground">
          {#if !session.org.logoUrl}
            {t('ui.settings.no_logo')}
          {:else if broken}
            {t('ui.settings.broken')}
          {:else}
            {t('ui.settings.preview')}
          {/if}
        </p>
      </div>

      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.settings.image_link')}</span>
        <input class="field" placeholder="https://" spellcheck="false" disabled={!logosOn} bind:value={url} oninput={() => logo.clear()} />
        <span class="text-xs {allowed ? 'text-muted-foreground' : 'text-destructive'}">
          {#if !logosOn}
            {t('ui.settings.logos_off')}
          {:else if allowed}
            {t('ui.settings.logo_hint', hostList)}
          {:else}
            {t('ui.settings.logo_host', hostList)}
          {/if}
        </span>
      </label>

      <div>
        <Button variant="primary" disabled={!allowed || unchanged || logo.busy} onclick={saveLogo}>
          {url.trim() === '' && session.org.logoUrl ? t('ui.settings.remove') : t('ui.settings.save')}
        </Button>
      </div>
      <ErrorText error={logo.error} />
    </section>

    <section class="flex w-140 shrink-0 flex-col gap-4">
      <div class="flex flex-col gap-1">
        <h2 class="text-base font-semibold">{t('ui.settings.sections')}</h2>
        <p class="text-13 text-muted-foreground">{t('ui.settings.sections_body')}</p>
      </div>

      <div class="flex flex-col rounded-lg border border-border">
        {#each features as entry (entry)}
          {@const text = featureText(entry)}
          <div class="flex items-center gap-4 border-b border-border px-4 py-3.5 last:border-b-0">
            <div class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="text-sm font-semibold">{text.title}</span>
              <span class="text-xs text-muted-foreground">{text.body}</span>
            </div>
            <Toggle label={text.title} checked={session.features[entry]} disabled={feature.busy} onchange={(enabled) => toggle(entry, enabled)} />
          </div>
        {/each}
      </div>
      <ErrorText error={feature.error} />
    </section>
  </Main>
</Body>
