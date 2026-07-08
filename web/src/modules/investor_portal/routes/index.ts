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
        redirect: { name: 'investor-portfolio-page' },
      },
      {
        path: 'portfolio',
        name: 'investor-portfolio-page',
        component: () => import('../pages/InvestorPortfolioPage.vue'),
        meta: { authScope: 'investor' },
      },
      {
        path: 'allocations',
        name: 'investor-allocations-page',
        component: () => import('../pages/InvestorAllocationsPage.vue'),
        meta: { authScope: 'investor' },
      },
      {
        path: 'profit',
        name: 'investor-profit-report-page',
        component: () => import('../pages/InvestorProfitReportPage.vue'),
        meta: { authScope: 'investor' },
      },
      {
        path: 'activity',
        name: 'investor-activity-page',
        component: () => import('../pages/InvestorActivityPage.vue'),
        meta: { authScope: 'investor' },
      },
    ],
  },
];

export default investorPortalRoutes;
