import type { RouteRecordRaw } from 'vue-router';

import { createInvestorAccessGuard } from 'src/modules/investor_portal/guards/investorAccessGuard';

const investorPortalRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/investor/login',
    alias: '/investor/login',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '',
        name: 'investor-login-page',
        component: () => import('../pages/InvestorLoginPage.vue'),
        meta: {
          authScope: 'investor',
          requiredScope: 'investor',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/investor',
    component: () => import('src/layouts/InvestorLayout.vue'),
    beforeEnter: createInvestorAccessGuard({
      loginRoute: 'investor-login-page',
    }),
    children: [
      {
        path: '',
        name: 'investor-dashboard-page',
        component: () => import('../pages/InvestorPortfolioPage.vue'),
        meta: { authScope: 'investor' },
      },
      {
        path: 'shipments',
        name: 'investor-shipments-page',
        component: () => import('../pages/InvestorAllocationsPage.vue'),
        meta: { authScope: 'investor' },
      },
      {
        path: 'portfolio',
        redirect: { name: 'investor-dashboard-page' },
      },
      {
        path: 'allocations',
        redirect: { name: 'investor-shipments-page' },
      },
      {
        path: 'profit',
        redirect: { name: 'investor-dashboard-page' },
      },
      {
        path: 'activity',
        redirect: { name: 'investor-dashboard-page' },
      },
    ],
  },
];

export default investorPortalRoutes;
