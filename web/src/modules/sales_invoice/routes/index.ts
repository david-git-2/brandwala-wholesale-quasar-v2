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

const salesInvoiceRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/sales/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-invoices-page',
        component: () => import('../pages/InvoicesListPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'billing-profiles',
        name: 'app-global-billing-profiles',
        component: () =>
          import('../pages/BillingProfilesPage.vue'),
        beforeEnter: guard('billing_profile'),
      },
      {
        path: 'recipient-profiles',
        name: 'app-global-recipient-profiles',
        component: () => import('../pages/RecipientProfilesPage.vue'),
        beforeEnter: guard('recipient_profile'),
      },
      {
        path: 'brands',
        name: 'app-global-invoice-brands',
        component: () => import('../pages/InvoiceBrandsPage.vue'),
        beforeEnter: guard('invoice_brand'),
      },
      {
        path: ':id',
        name: 'app-global-invoice-details-page',
        component: () => import('../pages/InvoiceDetailsPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/sales/invoices/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: guard('global_invoice'),
    children: [
      {
        path: '',
        name: 'app-global-invoice-preview',
        component: () => import('../pages/InvoicePreviewPage.vue'),
      },
    ],
  },
]

export default salesInvoiceRoutes
