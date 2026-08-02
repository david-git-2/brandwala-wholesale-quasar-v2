import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  allowedRoles: ['admin', 'staff'] as const,
  requireTenantContext: true,
};

const thriftSalesGuard = createAccessGuard({
  ...thriftGuard,
  requiredModule: 'thrift_sales',
});

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/sales',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: thriftSalesGuard,
    children: [
      {
        path: '',
        name: 'thrift-sales-page',
        component: () => import('../sales/pages/ThriftSalesPage.vue'),
        meta: {
          title: 'Thrift Sales',
          headerTitle: 'Thrift Sales',
        },
      },
      {
        path: 'create',
        name: 'thrift-sales-create',
        component: () => import('../sales/pages/ThriftCreateSalesInvoicePage.vue'),
        meta: {
          title: 'Create Sales Invoice',
          headerTitle: 'Create Sales Invoice',
        },
      },
      {
        path: ':invoiceId',
        name: 'thrift-sales-invoice-details',
        component: () => import('../sales/pages/ThriftSalesInvoiceDetailsPage.vue'),
        meta: {
          title: 'Sales Invoice Details',
          headerTitle: 'Sales Invoice Details',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/sales/:invoiceId/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: thriftSalesGuard,
    children: [
      {
        path: '',
        name: 'thrift-sales-invoice-print-preview',
        component: () => import('../sales/pages/ThriftSalesInvoicePrintPreviewPage.vue'),
        meta: {
          title: 'Sales Invoice Print Preview',
          headerTitle: 'Print Preview',
        },
      },
    ],
  },
];

export default routes;
