import { platformDocsSite } from './platformSite';
import type { DocsSiteDefinition, DocsSiteKey } from './types';

const sites: Partial<Record<DocsSiteKey, DocsSiteDefinition>> = {
  platform: platformDocsSite,
};

export function registerDocsSite(site: DocsSiteDefinition) {
  sites[site.key] = site;
}

export function getDocsSite(key: DocsSiteKey): DocsSiteDefinition {
  const site = sites[key];
  if (!site) {
    throw new Error(`getDocsSite: unknown or unregistered site "${key}"`);
  }
  return site;
}
