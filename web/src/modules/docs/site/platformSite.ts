import { getDocsMarkdown } from '../content/docsMarkdownRegistry';
import { docsNav } from '../content/nav';
import type { DocsSiteDefinition } from './types';

export const platformDocsSite: DocsSiteDefinition = {
  key: 'platform',
  basePath: '/docs',
  productTitle: 'Platform guide',
  siblingSiteKey: 'operating-manual',
  siblingLabel: 'Operating manual',
  nav: docsNav,
  overviewRouteName: 'docs-overview',
  searchPlaceholder: 'Search the guide',
  contentEditPathPrefix: 'web/src/modules/docs/content/md/',
  overviewEditPath: 'web/src/modules/docs/content/md/what-is-tradeflow.md',
  getMarkdown: getDocsMarkdown,
};
