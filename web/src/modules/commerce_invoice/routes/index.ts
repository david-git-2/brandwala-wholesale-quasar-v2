import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const commerceInvoiceRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-commerce-invoices',
        component: () => import('../pages/CommerceInvoicesPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'commerce_invoice',
        }),
      },
      {
        path: 'billing-profiles',
        name: 'app-commerce-billing-profiles',
        component: () => import('../pages/CommerceBillingProfilesPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'commerce_invoice',
        }),
      },
      {
        path: ':invoiceId',
        name: 'app-commerce-invoice-details',
        component: () => import('../pages/CommerceInvoiceDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'commerce_invoice',
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/commerce-shop/invoices/:invoiceId/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      requireTenantContext: true,
      allowedRoles: ['admin', 'staff'],
      requiredModule: 'commerce_invoice',
    }),
    children: [
      {
        path: '',
        name: 'app-commerce-invoice-preview',
        component: () => import('../pages/CommerceInvoicePreviewPage.vue'),
      },
    ],
  },
]

export default commerceInvoiceRoutes
