type Locales = Record<string, string>;

let dict: Locales = $state.raw({});

export function t(key: string, ...args: (string | number)[]): string {
  const template = dict[key];
  if (template == null) return key;
  let index = 0;
  return template.replace(/%[sd]/g, (placeholder) => {
    const value = args[index++];
    return value == null ? placeholder : String(value);
  });
}

export type Part = { text: string; value: boolean };

export function parts(key: string, ...args: (string | number)[]): Part[] {
  const template = dict[key] ?? key;
  const out: Part[] = [];
  let index = 0;
  let last = 0;

  for (const match of template.matchAll(/%[sd]/g)) {
    if (match.index > last) out.push({ text: template.slice(last, match.index), value: false });
    out.push({ text: String(args[index++] ?? match[0]), value: true });
    last = match.index + match[0].length;
  }

  if (last < template.length) out.push({ text: template.slice(last), value: false });
  return out;
}

function flatten(tree: unknown, prefix = '', into: Locales = {}): Locales {
  if (typeof tree === 'string') into[prefix] = tree;
  else if (typeof tree === 'object' && tree !== null)
    for (const [key, value] of Object.entries(tree)) flatten(value, prefix === '' ? key : `${prefix}.${key}`, into);
  return into;
}

async function loadDevLocales(): Promise<void> {
  const files = import.meta.glob<unknown>('../../../locales/en.json', { import: 'default' });
  const load = Object.values(files)[0];
  if (load) dict = flatten(await load());
}

export function setLocales(locales: Locales | undefined): void {
  if (locales && Object.keys(locales).length > 0) dict = locales;
  else if (import.meta.env.DEV) void loadDevLocales();
}
