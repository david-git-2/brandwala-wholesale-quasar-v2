import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftLedgerRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/ledger',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_accounting_ledger',
      }),
      children: [
         {
            path: '',
            name: 'thrift-ledger-page',
            component: () => import('../pages/ThriftLedgerPage.vue'),
            meta: {
               title: 'Thrift Accounting Ledger',
               headerTitle: 'General Ledger',
            },
         },
      ],
   },
];

export default thriftLedgerRoutes;
