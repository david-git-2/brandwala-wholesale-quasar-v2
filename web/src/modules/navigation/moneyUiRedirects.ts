import type { RouteLocationNormalized, RouteRecordRaw } from 'vue-router';

const appDashboardPath = (to: { params: Record<string, string | string[]> }) => {
  const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
  return tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard';
};

const legacyBillsRedirect =
  (suffix: string) =>
  (to: RouteLocationNormalized): string => {
    const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
    const base = tenantSlug ? `/${tenantSlug}/app/bills` : '/app/bills';
    const path = suffix ? `${base}/${suffix}` : base;
    const query =
      to.query && Object.keys(to.query).length
        ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
        : '';
    const hash = to.hash ?? '';
    return `${path}${query}${hash}`;
  };

/** Legacy money URLs → current desks. */
export const moneyUiRedirectRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/sales/invoices/:billId/preview',
    redirect: (to) => legacyBillsRedirect(`${to.params.billId}/preview`)(to),
  },
  {
    path: '/:tenantSlug?/app/sales/invoices/:billId/returns',
    redirect: (to) => legacyBillsRedirect(String(to.params.billId))(to),
  },
  {
    path: '/:tenantSlug?/app/sales/invoices/create',
    redirect: legacyBillsRedirect('create'),
  },
  {
    path: '/:tenantSlug?/app/sales/invoices/brands',
    redirect: legacyBillsRedirect('brands'),
  },
  {
    path: '/:tenantSlug?/app/sales/invoices/:billId',
    redirect: (to) => legacyBillsRedirect(String(to.params.billId))(to),
  },
  {
    path: '/:tenantSlug?/app/sales/invoices',
    redirect: legacyBillsRedirect(''),
  },
  {
    path: '/:tenantSlug?/app/invoices/:pathMatch(.*)*',
    redirect: legacyBillsRedirect(''),
  },
  {
    path: '/:tenantSlug?/app/wallet/entity/:pathMatch(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
      const tail =
        typeof to.params.pathMatch === 'string'
          ? `/entity/${to.params.pathMatch}`
          : Array.isArray(to.params.pathMatch)
            ? `/entity/${to.params.pathMatch.join('/')}`
            : '/entity';
      const base = tenantSlug ? `/${tenantSlug}/app/cashbook` : '/app/cashbook';
      return `${base}${tail}`;
    },
  },
  {
    path: '/:tenantSlug?/app/finance/payments/collect/:pathMatch(.*)*',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/finance/reports/payments',
    redirect: appDashboardPath,
  },
  {
    path: '/:tenantSlug?/app/finance/reports/wallet',
    redirect: appDashboardPath,
  },
];

export default moneyUiRedirectRoutes;
