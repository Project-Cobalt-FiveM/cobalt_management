export type Tab<V extends string> = { value: V; label: string; count?: number };

export type Option<V> = { value: V; label: string; dot?: string; swatch?: string };

export type Icon = import('svelte').Component<{ size?: string; class?: string }>;
