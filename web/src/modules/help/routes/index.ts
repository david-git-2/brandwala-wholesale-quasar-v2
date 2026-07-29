import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { createInvestorAccessGuard } from 'src/modules/investor_portal/guards/investorAccessGuard';
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

const helpRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/help',
    component: () => import('layouts/PlatformLayout.vue'),
    children: [
      {
        path: '',
        name: 'platform-help-center',
        component: () => import('../pages/HelpCenterPage.vue'),
        props: { helpScope: 'platform' },
        beforeEnter: createAccessGuard({
          loginRoute: 'superadmin-login-page',
          requiredScope: 'platform',
          allowedRoles: ['superadmin'],
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/help',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-help-center',
        component: () => import('../pages/HelpCenterPage.vue'),
        props: { helpScope: 'app' },
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff', 'viewer'],
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/shop/help',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-help-center',
        component: () => import('../pages/HelpCenterPage.vue'),
        props: { helpScope: 'shop' },
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/investor/help',
    component: () => import('layouts/InvestorLayout.vue'),
    beforeEnter: createInvestorAccessGuard({
      loginRoute: 'investor-login-page',
    }),
    children: [
      {
        path: '',
        name: 'investor-help-center',
        component: () => import('../pages/HelpCenterPage.vue'),
        props: { helpScope: 'investor' },
        meta: { authScope: 'investor' },
      },
    ],
  },
];

export default helpRoutes;
