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
    redirect: (to) => accountingRedirect(to, '/finance/payments'),
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments/:billingProfileId',
    redirect: (to) => accountingRedirect(to, '/finance/payments'),
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment',
    redirect: (to) => accountingRedirect(to, '/procurement/shipment'),
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
    redirect: (to) => accountingRedirect(to, '/procurement/shipment'),
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
    ],
  },
];

export default reportingTreasuryRoutes;
