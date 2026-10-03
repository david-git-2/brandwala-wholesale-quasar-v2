import type { RouteRecordRaw } from 'vue-router';

const appDashboardPath = (to: { params: Record<string, string | string[]> }) => {
  const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
  return tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard';
};

/** Nested legacy money URLs → dashboard. List URLs are real blank desks (bills_pays routes). */
export const moneyUiRedirectRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/sales/invoices/:pathMatch(.*)*',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/invoices/:pathMatch(.*)*',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/wallet/:pathMatch(.*)*',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/finance/payments/:pathMatch(.*)*',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/finance/reports/wallet',
    redirect: appDashboardPath,
  },
];

export default moneyUiRedirectRoutes;
