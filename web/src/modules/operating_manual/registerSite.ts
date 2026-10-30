import { registerDocsSite } from 'src/modules/docs/site/registry';
import type { DocsSiteDefinition } from 'src/modules/docs/site/types';
import { getOperatingManualMarkdown } from './content/markdownRegistry';
import { operatingManualNav } from './content/nav';

export const operatingManualDocsSite: DocsSiteDefinition = {
  key: 'operating-manual',
  basePath: '/operating-manual',
  productTitle: 'Operating manual',
  siblingSiteKey: 'platform',
  siblingLabel: 'Platform guide',
  nav: operatingManualNav,
  overviewRouteName: 'operating-manual-overview',
  searchPlaceholder: 'Search the manual',
  contentEditPathPrefix: 'web/src/modules/operating_manual/content/md/',
  overviewEditPath: 'web/src/modules/operating_manual/content/md/index.md',
  getMarkdown: getOperatingManualMarkdown,
};

registerDocsSite(operatingManualDocsSite);
