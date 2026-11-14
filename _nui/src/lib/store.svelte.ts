import { fetchNui } from './nui';
import { firstPage, canOpen } from './access';
import { setLocales, t } from './locale.svelte';
import type { Messages, OrgPage, Result, Session } from './types';

export type FundsMode = 'deposit' | 'withdraw';

export type GangPage = 'roster' | 'permissions' | 'vault' | 'archetype';

type Outcome = Result<Session> | { ok: boolean; error?: string };

class App {
  visible = $state(false);
  session = $state<Session | null>(null);
  orgPage = $state<OrgPage>('overview');
  gangPage = $state<GangPage>('roster');
  fundsMode = $state<FundsMode>('deposit');
  now = $state(Date.now());

  #offset = 0;
  #layers: (() => void)[] = [];

  constructor() {
    $effect.root(() => {
      $effect(() => {
        if (!this.visible) return;

        const timer = setInterval(() => (this.now = Date.now() + this.#offset), 15000);
        return () => clearInterval(timer);
      });
    });
  }

  replace(session: Session): void {
    this.#offset = new Date(session.now).getTime() - Date.now();
    this.now = Date.now() + this.#offset;
    this.session = session;

    if (session.mode === 'org' && !canOpen(session, this.orgPage)) this.orgPage = firstPage(session);
  }

  goOrg(page: OrgPage): void {
    if (this.session?.mode === 'org' && canOpen(this.session, page)) this.orgPage = page;
  }

  goGang(page: GangPage): void {
    this.gangPage = page;
  }

  pushLayer(close: () => void): () => void {
    this.#layers.push(close);
    return () => {
      this.#layers = this.#layers.filter((layer) => layer !== close);
    };
  }

  escape(): void {
    const layer = this.#layers.at(-1);
    if (layer) {
      layer();
      return;
    }

    this.close();
  }

  close(): void {
    if (!this.visible) return;

    this.visible = false;
    void fetchNui('close');
  }

  handle(message: Messages): void {
    switch (message.action) {
      case 'open':
        setLocales(message.locales);
        this.replace(message.data);
        if (message.data.mode === 'org') this.orgPage = firstPage(message.data);
        this.gangPage = 'roster';
        this.visible = true;
        break;
      case 'update':
        this.replace(message.data);
        break;
      case 'close':
        this.visible = false;
        break;
      default: {
        const exhaustive: never = message;
        return exhaustive;
      }
    }
  }
}

export const app = new App();

export class Action {
  busy = $state(false);
  error = $state<string | null>(null);

  async run(request: () => Promise<Outcome>): Promise<boolean> {
    if (this.busy) return false;

    this.busy = true;
    this.error = null;

    try {
      const reply = await request();

      if ('session' in reply) {
        app.replace(reply.session);
        return true;
      }

      if (reply.ok) return true;

      this.error = reply.error ?? t('ui.common.no_answer');
      return false;
    } catch {
      this.error = t('ui.common.no_answer');
      return false;
    } finally {
      this.busy = false;
    }
  }

  clear(): void {
    this.error = null;
  }
}
