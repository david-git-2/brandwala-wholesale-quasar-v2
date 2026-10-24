import { inject, provide, ref, type InjectionKey, type Ref } from 'vue';

export type DocsTocItem = {
  id: string;
  text: string;
  level: 2 | 3;
};

type DocsTocApi = {
  items: Ref<DocsTocItem[]>;
  setOwnerItems: (owner: string, next: DocsTocItem[]) => void;
  clearAllOwners: () => void;
};

const DOCS_TOC_KEY: InjectionKey<DocsTocApi> = Symbol('docs-toc');

export function provideDocsToc() {
  const owners = new Map<string, DocsTocItem[]>();
  const items = ref<DocsTocItem[]>([]);

  function rebuild() {
    items.value = [...owners.values()].flat();
  }

  function clearAllOwners() {
    owners.clear();
    rebuild();
  }

  const api: DocsTocApi = {
    items,
    setOwnerItems(owner, next) {
      if (next.length === 0) owners.delete(owner);
      else owners.set(owner, next);
      rebuild();
    },
    clearAllOwners,
  };

  provide(DOCS_TOC_KEY, api);
  return api;
}

export function useDocsTocOwner(owner: string) {
  const api = inject(DOCS_TOC_KEY, null);

  function setItems(next: DocsTocItem[]) {
    api?.setOwnerItems(owner, next);
  }

  // Owners are cleared on docs route change in DocsLayout — not on unmount — so the
  // "On this page" control does not flicker empty between pages.

  return { setItems, items: api?.items };
}

export function slugifyHeading(text: string): string {
  return text
    .replace(/`/g, '')
    .replace(/[*_]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-');
}

export function extractDocsToc(markdown: string): DocsTocItem[] {
  const items: DocsTocItem[] = [];
  const seen = new Map<string, number>();
  for (const line of markdown.replace(/\r\n/g, '\n').split('\n')) {
    const match = /^(#{2,3})\s+(.+)$/.exec(line);
    if (!match) continue;
    const level = match[1].length === 2 ? 2 : 3;
    const text = match[2].trim();
    let id = slugifyHeading(text);
    const count = seen.get(id) ?? 0;
    seen.set(id, count + 1);
    if (count > 0) id = `${id}-${count + 1}`;
    items.push({ id, text, level });
  }
  return items;
}

/** Same order as `extractDocsToc` — use when rendering h2/h3 in DocsMarkdown. */
export function createDocsHeadingIdQueue(markdown: string): () => string | undefined {
  const ids = extractDocsToc(markdown).map((item) => item.id);
  let index = 0;
  return () => ids[index++];
}

export type DocsTocGroup = {
  id: string;
  text: string;
  children: DocsTocItem[];
};

export function groupDocsTocItems(items: DocsTocItem[] | null | undefined): DocsTocGroup[] {
  const list = Array.isArray(items) ? items : [];
  const groups: DocsTocGroup[] = [];
  let current: DocsTocGroup | null = null;

  for (const item of list) {
    if (item.level === 2) {
      current = { id: item.id, text: item.text, children: [] };
      groups.push(current);
      continue;
    }
    if (current) {
      current.children.push(item);
    } else {
      groups.push({ id: item.id, text: item.text, children: [] });
    }
  }
  return groups;
}
