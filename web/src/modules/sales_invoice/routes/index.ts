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
        component: () => import('src/modules/global/pages/GlobalInvoicesPage.vue'),
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'billing-profiles',
        name: 'app-global-billing-profiles',
        component: () =>
          import('src/modules/commerce_invoice/pages/CommerceBillingProfilesPage.vue'),
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
        component: () => import('src/modules/invoice/pages/AdminInvoiceBrandsPage.vue'),
        beforeEnter: guard('invoice_brand'),
      },
      {
        path: ':id',
        name: 'app-global-invoice-details-page',
        component: () => import('src/modules/global/pages/GlobalInvoiceDetailsPage.vue'),
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
        component: () => import('src/modules/global/pages/GlobalInvoicePreviewPage.vue'),
      },
    ],
  },
]

export default salesInvoiceRoutes
