import type { RouteLocationNormalized, RouteRecordRaw } from 'vue-router';

const appDashboardPath = () => '/app/dashboard';

const legacyBillsRedirect =
  (suffix: string) =>
  (to: RouteLocationNormalized): string => {
    const base = '/app/bills';
    const path = suffix ? `${base}/${suffix}` : base;
    const query =
      to.query && Object.keys(to.query).length
        ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
        : '';
    const hash = to.hash ?? '';
    return `${path}${query}${hash}`;
  };

const legacyPaymentsRedirect =
  (suffix: string) =>
  (to: RouteLocationNormalized): string => {
    const base = '/app/payments';
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
    path: '/app/sales/invoices/:billId/preview',
    redirect: (to) => legacyBillsRedirect(`${to.params.billId}/preview`)(to),
  },
  {
    path: '/app/sales/invoices/:billId/returns',
    redirect: (to) => legacyBillsRedirect(String(to.params.billId))(to),
  },
  {
    path: '/app/sales/invoices/create',
    redirect: legacyBillsRedirect('create'),
  },
  {
    path: '/app/sales/invoices/brands',
    redirect: legacyBillsRedirect('brands'),
  },
  {
    path: '/app/sales/invoices/:billId',
    redirect: (to) => legacyBillsRedirect(String(to.params.billId))(to),
  },
  {
    path: '/app/sales/invoices',
    redirect: legacyBillsRedirect(''),
  },
  {
    path: '/app/invoices/:pathMatch(.*)*',
    redirect: legacyBillsRedirect(''),
  },
  {
    path: '/app/wallet/entity/:pathMatch(.*)*',
    redirect: (to) => {
      const tail =
        typeof to.params.pathMatch === 'string'
          ? `/entity/${to.params.pathMatch}`
          : Array.isArray(to.params.pathMatch)
            ? `/entity/${to.params.pathMatch.join('/')}`
            : '/entity';
      return `/app/cashbook${tail}`;
    },
  },
  {
    path: '/app/finance/payments/collect/:pathMatch(.*)*',
    redirect: (to) => {
      const base = '/app/payments/courier-remit';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `${base}${query}`;
    },
  },
  {
    path: '/app/finance/payments/collect',
    redirect: (to) => {
      const base = '/app/payments/courier-remit';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `${base}${query}`;
    },
  },
  {
    path: '/app/finance/payments/:pathMatch(.*)*',
    redirect: (to) => {
      const tail =
        typeof to.params.pathMatch === 'string'
          ? to.params.pathMatch
          : Array.isArray(to.params.pathMatch)
            ? to.params.pathMatch.join('/')
            : '';
      return legacyPaymentsRedirect(tail)(to);
    },
  },
  {
    path: '/app/finance/payments',
    redirect: legacyPaymentsRedirect(''),
  },
  {
    path: '/app/finance/reports/payments',
    redirect: appDashboardPath,
  },
  {
    path: '/app/finance/reports/wallet',
    redirect: '/app/finance/reports',
  },
];

export default moneyUiRedirectRoutes;
