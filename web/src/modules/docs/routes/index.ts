import type { RouteRecordRaw } from 'vue-router';

const topicPage = () => import('../pages/DocsTopicPage.vue');

const docsChildRoutes: RouteRecordRaw[] = [
  {
    path: '',
    name: 'docs-overview',
    component: () => import('../pages/DocsOverviewPage.vue'),
    meta: {
      title: 'What is TradeFlow?',
      public: true,
    },
  },
  {
    path: 'kernels',
    name: 'docs-kernels',
    component: topicPage,
    meta: {
      title: 'Kernels',
      docsMd: 'kernels.md',
      public: true,
    },
  },
  {
    path: 'scopes',
    name: 'docs-scopes',
    component: topicPage,
    meta: {
      title: 'Scopes',
      docsMd: 'scopes.md',
      public: true,
    },
  },
  {
    path: 'models',
    name: 'docs-models',
    component: topicPage,
    meta: {
      title: 'Sales models',
      docsMd: 'models.md',
      public: true,
    },
  },
  {
    path: 'modules/wholesale',
    name: 'docs-module-wholesale',
    component: topicPage,
    meta: {
      title: 'Wholesale',
      docsMd: 'module-wholesale.md',
      public: true,
    },
  },
  {
    path: 'modules/dropship',
    name: 'docs-module-dropship',
    component: topicPage,
    meta: {
      title: 'Dropship',
      docsMd: 'module-dropship.md',
      public: true,
    },
  },
  {
    path: 'modules/inbound',
    name: 'docs-module-inbound',
    component: topicPage,
    meta: {
      title: 'Inbound shipment',
      docsMd: 'module-inbound.md',
      public: true,
    },
  },
  {
    path: 'modules/money',
    name: 'docs-module-money',
    component: topicPage,
    meta: {
      title: 'Money',
      docsMd: 'module-money.md',
      public: true,
    },
  },
  {
    path: 'modules/tenant-shops',
    name: 'docs-module-tenant-shops',
    component: topicPage,
    meta: {
      title: 'Tenant & shops',
      docsMd: 'module-tenant-shops.md',
      public: true,
    },
  },
  {
    path: 'modules/tenants',
    name: 'docs-module-tenants',
    component: topicPage,
    meta: {
      title: 'Tenants',
      docsMd: 'module-tenants.md',
      public: true,
    },
  },
  {
    path: 'modules/shops',
    name: 'docs-module-shops',
    component: topicPage,
    meta: {
      title: 'Shops',
      docsMd: 'module-shops.md',
      public: true,
    },
  },
  {
    path: 'modules/shop',
    name: 'docs-module-shop',
    component: topicPage,
    meta: {
      title: 'Shop (storefront)',
      docsMd: 'module-shop.md',
      public: true,
    },
  },
  {
    path: 'modules/shop-admin',
    name: 'docs-module-shop-admin',
    component: topicPage,
    meta: {
      title: 'Shop admin',
      docsMd: 'module-shop-admin.md',
      public: true,
    },
  },
  {
    path: 'modules/product-based-costing',
    name: 'docs-module-pbc',
    component: topicPage,
    meta: {
      title: 'Product-based costing',
      docsMd: 'module-pbc.md',
      public: true,
    },
  },
  {
    path: 'modules/thrift',
    name: 'docs-module-thrift',
    component: topicPage,
    meta: {
      title: 'Thrift',
      docsMd: 'module-thrift.md',
      public: true,
    },
  },
];

const docsRoutes: RouteRecordRaw[] = [
  {
    path: '/docs',
    component: () => import('../layouts/DocsLayout.vue'),
    meta: { public: true },
    children: docsChildRoutes,
  },
];

export default docsRoutes;
