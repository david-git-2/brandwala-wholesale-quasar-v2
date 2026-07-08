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

const salesInvoiceRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/invoices',
    redirect: (to) => `${getTenantSlugPrefix(to.params)}/app/sales/invoices`,
  },
  {
    path: '/:tenantSlug?/app/invoices/billing-profiles',
    redirect: (to) => `${getTenantSlugPrefix(to.params)}/app/sales/invoices/billing-profiles`,
  },
  {
    path: '/:tenantSlug?/app/invoices/recipient-profiles',
    redirect: (to) => `${getTenantSlugPrefix(to.params)}/app/sales/invoices/recipient-profiles`,
  },
  {
    path: '/:tenantSlug?/app/invoices/brands',
    redirect: (to) => `${getTenantSlugPrefix(to.params)}/app/sales/invoices/brands`,
  },
  {
    path: '/:tenantSlug?/app/invoices/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params);
      const id = typeof to.params.id === 'string' ? to.params.id : '';
      return `${prefix}/app/sales/invoices/${id}`;
    },
  },
  {
    path: '/:tenantSlug?/app/invoices/:id/preview',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params);
      const id = typeof to.params.id === 'string' ? to.params.id : '';
      return `${prefix}/app/sales/invoices/${id}/preview`;
    },
  },
  {
    path: '/:tenantSlug?/app/sales/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-global-invoices-page',
        component: () => import('../pages/InvoicesListPage.vue'),
        meta: {
          hasPageToolbar: true,
        },
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'billing-profiles',
        name: 'app-global-billing-profiles',
        component: () => import('../pages/BillingProfilesPage.vue'),
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
];

export default salesInvoiceRoutes;
