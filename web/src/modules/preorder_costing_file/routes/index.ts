import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { createShopAccessGuard } from 'src/modules/auth/guards/createShopAccessGuard';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { validateAppRouteTenantSlug } from 'src/modules/tenant/utils/tenantRouteContext';

const resolveAppCostingLanding = () => {
  const authStore = useAuthStore();

  if (authStore.matchedRole === 'viewer') {
    return { name: 'viewer-costing-file-page' };
  }

  if (authStore.matchedRole === 'staff') {
    return { name: 'staff-costing-file-page' };
  }

  return { name: 'admin-costing-file-page' };
};

const costingFileRoutes: RouteRecordRaw[] = [
  {
    path: '/app/costing',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff', 'viewer'],
      requireTenantContext: true,
      requiredModule: 'costing_file',
      validateAccess: ({ authStore, to }) => validateAppRouteTenantSlug({ authStore, to }),
    }),
    children: [
      {
        path: '',
        name: 'costing-file-entry',
        redirect: resolveAppCostingLanding,
      },
      {
        path: 'admin',
        name: 'admin-costing-file-page',
        component: () => import('../pages/AdminCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'admin/:id',
        name: 'admin-costing-file-details-page',
        component: () => import('../pages/AdminCostingFileDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'admin/:id/viewers',
        name: 'admin-costing-file-viewers-page',
        component: () => import('../pages/AdminCostingFileViewersPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'staff',
        name: 'staff-costing-file-page',
        component: () => import('../pages/StaffCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['staff'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'staff/:id',
        name: 'staff-costing-file-details-page',
        component: () => import('../pages/StaffCostingFileDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['staff'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'viewer',
        name: 'viewer-costing-file-page',
        component: () => import('../pages/ViewerCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['viewer'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'viewer/:id',
        name: 'viewer-costing-file-details-page',
        component: () => import('../pages/ViewerCostingFileDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['viewer'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
    ],
  },
  {
    path: '/shop/:tenantSlug/costing',
    redirect: (to) => `/shop/${String(to.params.tenantSlug ?? '')}/catalog/costing`,
  },
  {
    path: '/shop/:tenantSlug/:shopType(catalog|stock|dropship)/costing',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'customer-costing-file-page',
        component: () => import('../pages/CustomerCostingFilePage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'costing_file' }),
      },
      {
        path: ':id',
        name: 'customer-costing-file-details-page',
        component: () => import('../pages/CustomerCostingFileDetailsPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'costing_file' }),
      },
    ],
  },
  {
    path: '/shop/:tenantSlug/costing/:id/preview',
    redirect: (to) =>
      `/shop/${String(to.params.tenantSlug ?? '')}/catalog/costing/${String(to.params.id ?? '')}/preview`,
  },
  {
    path: '/shop/:tenantSlug/:shopType(catalog|stock|dropship)/costing/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'customer-costing-file-preview-page',
        component: () => import('../pages/CustomerCostingFilePreviewPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'costing_file' }),
      },
    ],
  },
  {
    path: '/app/costing/admin/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'admin-costing-file-preview-page',
        component: () => import('../pages/AdminCostingFilePreviewPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
    ],
  },
];

export default costingFileRoutes;
