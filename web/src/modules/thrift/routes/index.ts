import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  allowedRoles: ['admin', 'staff'] as const,
  requireTenantContext: true,
};

const thriftRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/shipments',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_shipment',
    }),
    children: [
      {
        path: '',
        name: 'thrift-shipments-page',
        component: () => import('../pages/ThriftShipmentPage.vue'),
        meta: {
          title: 'Thrift Shipments',
          headerTitle: 'Thrift Shipments',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/boxes',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_box',
    }),
    children: [
      {
        path: '',
        name: 'thrift-boxes-page',
        component: () => import('../pages/ThriftBoxPage.vue'),
        meta: {
          title: 'Thrift Boxes',
          headerTitle: 'Thrift Boxes',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/shelves',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_shelf',
    }),
    children: [
      {
        path: '',
        name: 'thrift-shelves-page',
        component: () => import('../pages/ThriftShelfPage.vue'),
        meta: {
          title: 'Thrift Shelves',
          headerTitle: 'Thrift Shelves',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/categories',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_category',
    }),
    children: [
      {
        path: '',
        name: 'thrift-categories-page',
        component: () => import('../pages/ThriftCategoryPage.vue'),
        meta: {
          title: 'Thrift Categories',
          headerTitle: 'Thrift Categories',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/types',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_type',
    }),
    children: [
      {
        path: '',
        name: 'thrift-types-page',
        component: () => import('../pages/ThriftTypePage.vue'),
        meta: {
          title: 'Thrift Types',
          headerTitle: 'Thrift Types',
        },
      },
    ],
  },
];

export default thriftRoutes;
