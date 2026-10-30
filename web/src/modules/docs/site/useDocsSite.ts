import { inject, type ComputedRef, type InjectionKey } from 'vue';
import { getDocsSite } from './registry';
import type { DocsSiteDefinition, DocsSiteKey } from './types';

export const DOCS_SITE_KEY: InjectionKey<ComputedRef<DocsSiteDefinition>> = Symbol('docs-site');

export function useDocsSite(): ComputedRef<DocsSiteDefinition> {
  const site = inject(DOCS_SITE_KEY, null);
  if (!site) {
    throw new Error('useDocsSite: missing DocsSiteDefinition (wrap route in DocsLayout with meta.docsSiteKey)');
  }
  return site;
}

export function resolveDocsSiteKey(raw: unknown): DocsSiteKey {
  if (raw === 'operating-manual') return 'operating-manual';
  return 'platform';
}

export function siblingDocsSite(site: DocsSiteDefinition): DocsSiteDefinition | null {
  if (!site.siblingSiteKey) return null;
  return getDocsSite(site.siblingSiteKey);
}
