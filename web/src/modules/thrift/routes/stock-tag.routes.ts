import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftStockTagRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/stock-tags',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'thrift_stock',
    }),
    children: [
      {
        path: '',
        name: 'thrift-stock-tags-picker',
        component: () => import('../stock/pages/ThriftStockTagPrintPage.vue'),
        meta: {
          title: 'Print Marketing Tags',
          headerTitle: 'Marketing Tags',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/stock-tags/:shipmentId/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'thrift_stock',
    }),
    children: [
      {
        path: '',
        name: 'thrift-stock-tag-print-preview',
        component: () => import('../stock/pages/ThriftStockTagPrintPreviewPage.vue'),
        meta: {
          title: 'Marketing Tag Print Preview',
          headerTitle: 'Print Preview',
        },
      },
    ],
  },
];

export default thriftStockTagRoutes;
