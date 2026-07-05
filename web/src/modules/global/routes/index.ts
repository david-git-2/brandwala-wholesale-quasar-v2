import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry'

const guard = (requiredModule: ModuleKey, allowedRoles: ('admin' | 'staff')[] = ['admin', 'staff']) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    allowedRoles,
    requiredModule,
  })

const globalRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/global/stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-stock-page',
        component: () => import('../pages/GlobalStockPage.vue'),
        beforeEnter: guard('global_stock'),
      },
      {
        path: 'allocate',
        name: 'app-global-stock-allocate-page',
        component: () => import('../pages/TenantStockPage.vue'),
        beforeEnter: guard('global_stock'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/invoices',
    redirect: (to) => ({
      name: 'app-global-invoices-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },
  {
    path: '/:tenantSlug?/app/global/invoices/billing-profiles',
    redirect: (to) => ({
      name: 'app-global-billing-profiles',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },
  {
    path: '/:tenantSlug?/app/global/invoices/brands',
    redirect: (to) => ({
      name: 'app-global-invoice-brands',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },
  {
    path: '/:tenantSlug?/app/global/invoices/:id',
    redirect: (to) => ({
      name: 'app-global-invoice-details-page',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
    }),
  },
  {
    path: '/:tenantSlug?/app/global/invoices/:id/preview',
    redirect: (to) => ({
      name: 'app-global-invoice-preview',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
    }),
  },
  {
    path: '/:tenantSlug?/app/global/accounting/ledger',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-ledger-page',
        component: () => import('../pages/GlobalLedgerPage.vue'),
        beforeEnter: guard('global_accounting_ledger'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/accounting/shipments',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-shipment-accounting-page',
        component: () => import('../pages/GlobalShipmentAccountingPage.vue'),
        beforeEnter: guard('global_shipment_accounting'),
      },
      {
        path: ':id',
        name: 'app-global-shipment-accounting-details-page',
        component: () => import('../pages/GlobalShipmentAccountingDetailsPage.vue'),
        beforeEnter: guard('global_shipment_accounting'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/accounting/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-invoice-accounting-page',
        component: () => import('../pages/GlobalInvoiceAccountingPage.vue'),
        beforeEnter: guard('global_invoice_accounting'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/investors',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-investors-page',
        component: () => import('../pages/GlobalInvestorsPage.vue'),
        beforeEnter: guard('global_investor'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/investor-shipments',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-investor-shipments-page',
        component: () => import('../pages/GlobalInvestorShipmentsPage.vue'),
        beforeEnter: guard('global_investor_shipment'),
      },
    ],
  },
]

export default globalRoutes
