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
  `${getTenantSlugPrefix(to.params)}/app/finance${suffix}`;

const reportingTreasuryRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/accounting/invoice',
    redirect: (to) => accountingRedirect(to, '/invoices'),
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments',
    redirect: (to) => accountingRedirect(to, '/balances'),
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments/:billingProfileId',
    redirect: (to) => accountingRedirect(to, '/balances'),
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment',
    redirect: (to) => accountingRedirect(to, '/shipments'),
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params);
      const id = typeof to.params.id === 'string' ? to.params.id : '';
      return `${prefix}/app/finance/shipments/${id}`;
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/inventory-shipment',
    redirect: (to) => accountingRedirect(to, '/shipments'),
  },
  {
    path: '/:tenantSlug?/app/finance',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: 'payments',
        name: 'app-finance-payments-page',
        component: () => import('../pages/PaymentsListPage.vue'),
        beforeEnter: guard('payments'),
      },
      {
        path: 'payments/:id',
        name: 'app-finance-payment-details-page',
        component: () => import('../pages/PaymentDetailPage.vue'),
        beforeEnter: guard('payments'),
      },
      {
        path: 'invoices',
        name: 'app-finance-invoices-page',
        component: () => import('../pages/InvoiceMarginReportPage.vue'),
        beforeEnter: guard('invoice_reports'),
      },
      {
        path: 'invoices/:id',
        name: 'app-finance-invoice-margin-details-page',
        component: () => import('../pages/InvoiceMarginDetailPage.vue'),
        beforeEnter: guard('invoice_reports'),
      },
      {
        path: 'shipments',
        name: 'app-finance-shipments-page',
        component: () => import('../pages/ShipmentsListPage.vue'),
        beforeEnter: guard('shipment_reports'),
      },
      {
        path: 'shipments/:id',
        name: 'app-finance-shipment-details-page',
        component: () => import('../pages/ShipmentPnLDetailsPage.vue'),
        beforeEnter: guard('shipment_reports'),
      },
      {
        path: 'balances',
        name: 'app-finance-balances-page',
        component: () => import('../pages/BillingBalancesPage.vue'),
        beforeEnter: guard('billing_balances'),
      },
      {
        path: 'dashboard',
        name: 'app-finance-dashboard-page',
        component: () => import('../pages/ParentDashboardPage.vue'),
        beforeEnter: guard('parent_dashboard'),
      },
      {
        path: 'investors',
        name: 'app-finance-investors-page',
        component: () => import('../pages/InvestorReportsPage.vue'),
        beforeEnter: guard('investor_reports'),
      },
    ],
  },
];

export default reportingTreasuryRoutes;
