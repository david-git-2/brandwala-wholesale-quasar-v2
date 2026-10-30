import type { DocsNavEntry } from '../content/nav';

export type DocsSiteKey = 'platform' | 'operating-manual';

export type DocsSiteDefinition = {
  key: DocsSiteKey;
  basePath: string;
  productTitle: string;
  /** Other public doc site for toolbar cross-link */
  siblingSiteKey?: DocsSiteKey;
  siblingLabel?: string;
  nav: DocsNavEntry[];
  overviewRouteName: string;
  searchPlaceholder: string;
  contentEditPathPrefix: string;
  getMarkdown: (filename: string) => string | undefined;
  overviewEditPath?: string;
};
