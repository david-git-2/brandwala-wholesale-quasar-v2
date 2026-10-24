export type DocsNavItem = {
  label: string;
  name: string;
  path: string;
};

export type DocsNavGroup = {
  label: string;
  children: DocsNavItem[];
};

export type DocsNavEntry = DocsNavItem | DocsNavGroup;

export function isDocsNavGroup(entry: DocsNavEntry): entry is DocsNavGroup {
  return 'children' in entry;
}

/** Sidebar order. Paths are derived from route `name` as `/docs/<segment>`. */
export type DocsNavFlatItem = DocsNavItem & { group: string };

export function flattenDocsNav(entries: DocsNavEntry[] = docsNav): DocsNavFlatItem[] {
  const items: DocsNavFlatItem[] = [];
  for (const entry of entries) {
    if (isDocsNavGroup(entry)) {
      for (const child of entry.children) {
        items.push({ ...child, group: entry.label });
      }
    } else {
      items.push({ ...entry, group: '' });
    }
  }
  return items;
}

export function findDocsNavContext(routeName: string | symbol | null | undefined) {
  const items = flattenDocsNav();
  const index = items.findIndex((item) => item.name === routeName);
  const current = index >= 0 ? items[index] : undefined;
  return {
    current,
    previous: index > 0 ? items[index - 1] : undefined,
    next: index >= 0 && index < items.length - 1 ? items[index + 1] : undefined,
  };
}

/** Modules ordered by dependency / operator value (top = read first). Thrift stays in the list. */
export const docsNav: DocsNavEntry[] = [
  {
    label: 'What is TradeFlow?',
    name: 'docs-overview',
    path: '/docs',
  },
  {
    label: 'Platform',
    children: [
      { label: 'Kernels', name: 'docs-kernels', path: '/docs/kernels' },
      { label: 'Scopes', name: 'docs-scopes', path: '/docs/scopes' },
      { label: 'Sales models', name: 'docs-models', path: '/docs/models' },
    ],
  },
  {
    label: 'Modules',
    children: [
      { label: 'Tenants', name: 'docs-module-tenants', path: '/docs/modules/tenants' },
      { label: 'Money', name: 'docs-module-money', path: '/docs/modules/money' },
      { label: 'Inbound shipment', name: 'docs-module-inbound', path: '/docs/modules/inbound' },
      { label: 'Wholesale', name: 'docs-module-wholesale', path: '/docs/modules/wholesale' },
      { label: 'Shop (storefront)', name: 'docs-module-shop', path: '/docs/modules/shop' },
      { label: 'Shop admin', name: 'docs-module-shop-admin', path: '/docs/modules/shop-admin' },
      { label: 'Dropship', name: 'docs-module-dropship', path: '/docs/modules/dropship' },
      { label: 'Product-based costing', name: 'docs-module-pbc', path: '/docs/modules/product-based-costing' },
      { label: 'Thrift', name: 'docs-module-thrift', path: '/docs/modules/thrift' },
    ],
  },
];
