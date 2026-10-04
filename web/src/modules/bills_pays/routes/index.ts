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

const billsPaysRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/sales/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-bills-page',
        component: () => import('../pages/BillsPage.vue'),
        meta: { hasPageToolbar: true, title: 'Bills', headerTitle: 'Bills' },
        beforeEnter: guard('global_invoice'),
      },
      {
        path: ':billId',
        name: 'app-bill-detail-page',
        component: () => import('../pages/BillDetailPage.vue'),
        meta: { hasPageToolbar: true, title: 'Bill', headerTitle: 'Bill' },
        beforeEnter: guard('global_invoice'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/finance/payments',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-payments-page',
        component: () => import('../pages/PaymentsPage.vue'),
        meta: { hasPageToolbar: true, title: 'Payments', headerTitle: 'Payments' },
        beforeEnter: guard('payments'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/wallet',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-cashbook-page',
        component: () => import('../pages/CashbookPage.vue'),
        meta: { hasPageToolbar: true, title: 'Cashbook', headerTitle: 'Cashbook' },
        beforeEnter: guard('universal_wallet'),
      },
    ],
  },
];

export default billsPaysRoutes;
