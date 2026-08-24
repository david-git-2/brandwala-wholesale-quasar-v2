import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const getTenantSlugPrefix = (params: Record<string, string | string[]>) => {
  const tenantSlug = typeof params.tenantSlug === 'string' ? params.tenantSlug : '';
  return tenantSlug ? `/${tenantSlug}` : '';
};

const accountingRedirect = (to: { params: Record<string, string | string[]> }, suffix: string) =>
  `${getTenantSlugPrefix(to.params)}/app${suffix}`;

const reportingTreasuryRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/accounting/invoice',
    redirect: (to) => accountingRedirect(to, '/sales/invoices'),
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments',
    redirect: (to) => accountingRedirect(to, '/finance/reports'),
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments/:billingProfileId',
    redirect: (to) => accountingRedirect(to, '/finance/reports'),
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment',
    redirect: (to) => accountingRedirect(to, '/procurement'),
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params);
      const id = typeof to.params.id === 'string' ? to.params.id : '';
      return `${prefix}/app/procurement/shipment/${id}`;
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/inventory-shipment',
    redirect: (to) => accountingRedirect(to, '/procurement'),
  },
  {
    path: '/:tenantSlug?/app/finance',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: 'reports',
        name: 'app-finance-reports-page',
        component: () => import('../pages/ReportsOverviewPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Reports', headerTitle: 'Reports' },
      },
      {
        path: 'reports/cash-in',
        name: 'app-finance-cash-in-report-page',
        component: () => import('../pages/CashInReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Cash in', headerTitle: 'Cash in' },
      },
      {
        path: 'reports/customer-dues',
        name: 'app-finance-customer-dues-report-page',
        component: () => import('../pages/CustomerDuesReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Customer dues', headerTitle: 'Customer dues' },
      },
      {
        path: 'reports/invoice-book',
        name: 'app-finance-invoice-book-report-page',
        component: () => import('../pages/InvoiceBookReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Invoice book', headerTitle: 'Invoice book' },
      },
      {
        path: 'reports/invoice-profit',
        name: 'app-finance-invoice-profit-report-page',
        component: () => import('../pages/InvoiceProfitReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Invoice / product profit', headerTitle: 'Invoice / product profit' },
      },
      {
        path: 'reports/shipment-profit',
        name: 'app-finance-shipment-profit-report-page',
        component: () => import('../pages/ShipmentProfitReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Shipment cost and profit', headerTitle: 'Shipment cost and profit' },
      },
      {
        path: 'reports/wallet',
        name: 'app-finance-wallet-report-page',
        component: () => import('../pages/WalletReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Wallet', headerTitle: 'Wallet' },
      },
      {
        path: 'reports/courier-cod',
        name: 'app-finance-courier-cod-report-page',
        component: () => import('../pages/CourierCodReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Courier COD', headerTitle: 'Courier COD' },
      },
      {
        path: 'reports/month-snapshot',
        name: 'app-finance-month-snapshot-report-page',
        component: () => import('../pages/MonthSnapshotReportPage.vue'),
        beforeEnter: guard('reporting_treasury'),
        meta: { title: 'Month snapshot', headerTitle: 'Month snapshot' },
      },
    ],
  },
];

export default reportingTreasuryRoutes;
