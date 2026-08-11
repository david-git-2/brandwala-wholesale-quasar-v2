import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';
import { showWarningDialog } from 'src/utils/appFeedback';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  requireTenantContext: true,
};

const thriftSalesGuard = createAccessGuard({
  ...thriftGuard,
  requiredModule: 'thrift_sales',
});

const thriftSalesCreateGuard = createAccessGuard({
  ...thriftGuard,
  requiredModule: 'thrift_sales',
  validateAccess: ({ authStore }) => {
    const accessArgs = {
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey: 'thrift_sales' as const,
      activeModuleKeys: authStore.activeModuleKeys,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    };

    const canCreateOrEdit =
      canAccessModule({ ...accessArgs, action: 'create' }) ||
      canAccessModule({ ...accessArgs, action: 'edit' });

    if (canCreateOrEdit) {
      return true;
    }

    showWarningDialog('You do not have permission to access this page.', 'Access denied');
    const tenantSlug = authStore.tenantSlug;
    return tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard';
  },
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
        beforeEnter: thriftSalesCreateGuard,
        meta: {
          title: 'Create Sales Invoice',
          headerTitle: 'Create Sales Invoice',
        },
      },
      {
        path: 'returns',
        name: 'thrift-sales-returns',
        component: () => import('../sales/pages/ThriftSalesReturnsPage.vue'),
        meta: {
          title: 'Thrift Returns',
          headerTitle: 'Returns',
        },
      },
      {
        path: 'returns/:returnId',
        name: 'thrift-sales-return-details',
        component: () => import('../sales/pages/ThriftSalesReturnDetailsPage.vue'),
        meta: {
          title: 'Return Details',
          headerTitle: 'Return Details',
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
