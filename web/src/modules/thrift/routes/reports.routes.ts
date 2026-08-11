import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  requireTenantContext: true,
};

const thriftReportsGuard = createAccessGuard({
  ...thriftGuard,
  requiredModule: 'thrift_reports',
});

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/reports',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: thriftReportsGuard,
    children: [
      {
        path: '',
        name: 'thrift-reports-page',
        component: () => import('../reports/pages/ThriftReportsPage.vue'),
        meta: {
          title: 'Thrift Reports',
          headerTitle: 'Reports',
        },
      },
      {
        path: 'sales',
        name: 'thrift-sales-report',
        component: () => import('../reports/pages/ThriftSalesReportPage.vue'),
        meta: {
          title: 'How much did I earn?',
          headerTitle: 'How much did I earn?',
        },
      },
      {
        path: 'cod',
        name: 'thrift-cod-report',
        component: () => import('../reports/pages/ThriftCodReportPage.vue'),
        meta: {
          title: 'Money still coming',
          headerTitle: 'Money still coming',
        },
      },
      {
        path: 'shipments',
        name: 'thrift-shipment-reports-list',
        component: () => import('../reports/pages/ThriftShipmentReportsListPage.vue'),
        meta: {
          title: 'Was this purchase worth it?',
          headerTitle: 'Was this purchase worth it?',
        },
      },
      {
        path: ':shipmentId',
        name: 'thrift-report-details',
        component: () => import('../reports/pages/ThriftReportDetailsPage.vue'),
        meta: {
          title: 'Purchase profit',
          headerTitle: 'Purchase profit',
        },
      },
    ],
  },
];

export default routes;
