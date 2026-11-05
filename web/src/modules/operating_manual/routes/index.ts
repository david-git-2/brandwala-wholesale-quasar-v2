import type { RouteRecordRaw } from 'vue-router';
import '../registerSite';

const topicPage = () => import('src/modules/docs/pages/DocsTopicPage.vue');

const operatingManualRoutes: RouteRecordRaw[] = [
  {
    path: '/operating-manual',
    component: () => import('src/modules/docs/layouts/DocsLayout.vue'),
    meta: { public: true, docsSiteKey: 'operating-manual' },
    children: [
      {
        path: '',
        name: 'operating-manual-overview',
        component: topicPage,
        meta: {
          title: 'Operating manual',
          docsMd: 'index.md',
          public: true,
        },
      },
      {
        path: 'document-numbering',
        name: 'operating-manual-document-numbering',
        component: topicPage,
        meta: {
          title: 'Document numbers',
          docsMd: 'document-numbering.md',
          public: true,
        },
      },
    ],
  },
];

export default operatingManualRoutes;
