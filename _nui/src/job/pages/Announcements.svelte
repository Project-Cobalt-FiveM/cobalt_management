<script lang="ts">
  import Megaphone from 'phosphor-svelte/lib/Megaphone';
  import TopBar from '../../components/shell/TopBar.svelte';
  import Body from '../../components/shell/Body.svelte';
  import Main from '../../components/shell/Main.svelte';
  import Side from '../../components/shell/Side.svelte';
  import Button from '../../components/ui/Button.svelte';
  import TextArea from '../../components/ui/TextArea.svelte';
  import ErrorText from '../../components/ui/ErrorText.svelte';
  import { Action } from '../../lib/store.svelte';
  import { fetchNui } from '../../lib/nui';
  import { shortDate } from '../../lib/format';
  import { t } from '../../lib/locale.svelte';
  import type { JobSession } from '../../lib/types';

  let { session }: { session: JobSession } = $props();

  const post = new Action();

  let title = $state('');
  let message = $state('');

  const valid = $derived(title.trim().length > 0 && message.trim().length > 0);

  async function submit() {
    if (!valid) return;

    const payload = { title: title.trim(), message: message.trim() };
    if (await post.run(() => fetchNui('postAnnouncement', payload))) {
      title = '';
      message = '';
    }
  }
</script>

<TopBar title={t('ui.page.announcements')} subtitle={t('ui.announcements.subtitle', session.job.label)} />

<Body>
  <Main class="px-12">
    <div class="flex max-w-180 flex-col">
      {#each session.announcements as announcement (announcement.id)}
        <article class="flex flex-col gap-2 border-b border-border py-5 first:pt-0 last:border-b-0">
          <div class="flex items-baseline gap-4">
            <h2 class="flex-1 text-base font-semibold">{announcement.title}</h2>
            <span class="shrink-0 text-xs text-muted-foreground">{t('ui.common.by_on', announcement.author, shortDate(announcement.createdAt))}</span>
          </div>
          <p class="text-sm leading-[1.375rem] whitespace-pre-line text-muted-foreground">{announcement.message}</p>
        </article>
      {:else}
        <p class="text-13 text-muted-foreground">{t('ui.common.no_announcements')}</p>
      {/each}
    </div>
  </Main>

  {#if session.access.announce}
    <Side width="w-105" class="gap-4">
      <h2 class="text-base font-semibold">{t('ui.announcements.new')}</h2>
      <label class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.common.title')}</span>
        <input class="field" placeholder={t('ui.announcements.title_placeholder')} maxlength={session.limits.title} bind:value={title} oninput={() => post.clear()} />
      </label>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-semibold">{t('ui.common.message')}</span>
        <TextArea
          label={t('ui.common.message')}
          placeholder={t('ui.announcements.message_placeholder')}
          max={session.limits.message}
          hint={t('ui.announcements.hint')}
          bind:value={message}
        />
      </div>
      <Button variant="primary" class="w-full" disabled={!valid || post.busy} onclick={submit}><Megaphone size="1rem" />{t('ui.announcements.post')}</Button>
      <ErrorText error={post.error} />
    </Side>
  {/if}
</Body>
