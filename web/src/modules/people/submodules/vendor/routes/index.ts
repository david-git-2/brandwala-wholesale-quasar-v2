import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { validateAppRouteTenantSlug } from 'src/modules/tenant/utils/tenantRouteContext';

const vendorRoutes: RouteRecordRaw[] = [
  {
    path: '/app/vendors',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'vendor',
      validateAccess: ({ authStore, to }) => validateAppRouteTenantSlug({ authStore, to }),
    }),
    children: [
      {
        path: '',
        name: 'app-vendors-page',
        component: () => import('../pages/VendorsPage.vue'),
      },
      {
        path: ':id',
        name: 'app-vendor-details-page',
        component: () => import('../pages/VendorDetailsPage.vue'),
      },
    ],
  },
  {
    path: '/platform/vendors',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'platform-vendors-page',
        component: () => import('../pages/VendorsPage.vue'),
      },
      {
        path: ':id',
        name: 'platform-vendor-details-page',
        component: () => import('../pages/VendorDetailsPage.vue'),
      },
    ],
  },
];

export default vendorRoutes;
