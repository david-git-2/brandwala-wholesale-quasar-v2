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
          headerTitle: 'Thrift Reports',
        },
      },
      {
        path: 'sales',
        name: 'thrift-sales-report',
        component: () => import('../reports/pages/ThriftSalesReportPage.vue'),
        meta: {
          title: 'Thrift Sales Report',
          headerTitle: 'Thrift Sales Report',
        },
      },
      {
        path: ':shipmentId',
        name: 'thrift-report-details',
        component: () => import('../reports/pages/ThriftReportDetailsPage.vue'),
        meta: {
          title: 'Shipment Sales Report',
          headerTitle: 'Shipment Sales Report',
        },
      },
    ],
  },
];

export default routes;
