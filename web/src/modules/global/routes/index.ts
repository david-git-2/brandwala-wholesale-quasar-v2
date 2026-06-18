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
    ],
  },
  {
    path: '/:tenantSlug?/app/global/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-invoices-page',
        component: () => import('../pages/GlobalInvoicesPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'billing-profiles',
        name: 'app-global-billing-profiles',
        component: () =>
          import('src/modules/commerce_invoice/pages/CommerceBillingProfilesPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'brands',
        name: 'app-global-invoice-brands',
        component: () => import('src/modules/invoice/pages/AdminInvoiceBrandsPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
      {
        path: ':id',
        name: 'app-global-invoice-details-page',
        component: () => import('../pages/GlobalInvoiceDetailsPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/global/invoices/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: guard('global_invoice'),
    children: [
      {
        path: '',
        name: 'app-global-invoice-preview',
        component: () => import('../pages/GlobalInvoicePreviewPage.vue'),
      },
    ],
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
