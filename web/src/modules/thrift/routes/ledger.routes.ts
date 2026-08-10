import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  requireTenantContext: true,
};

const thriftLedgerGuard = createAccessGuard({
  ...thriftGuard,
  requiredModule: 'thrift_reports',
});

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/ledger',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: thriftLedgerGuard,
    children: [
      {
        path: '',
        name: 'thrift-ledger-page',
        component: () => import('../ledger/pages/ThriftLedgerPage.vue'),
        meta: {
          title: 'Thrift Ledger',
          headerTitle: 'Thrift Ledger',
        },
      },
    ],
  },
];

export default routes;
