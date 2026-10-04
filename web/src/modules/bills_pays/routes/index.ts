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
        path: 'create',
        name: 'app-bill-compose-page',
        component: () => import('../pages/BillComposePage.vue'),
        meta: { hasPageToolbar: true, title: 'New bill', headerTitle: 'New bill' },
        beforeEnter: guard('global_invoice'),
      },
      {
        path: 'brands',
        name: 'app-bill-brands-page',
        component: () => import('../pages/BillBrandsPage.vue'),
        meta: { hasPageToolbar: true, title: 'Invoice brands', headerTitle: 'Invoice brands' },
        beforeEnter: guard('global_invoice'),
      },
      {
        path: ':billId/preview',
        name: 'app-bill-preview-page',
        component: () => import('../pages/BillPreviewPage.vue'),
        meta: { hasPageToolbar: true, title: 'Print bill', headerTitle: 'Print bill' },
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
      {
        path: 'collect',
        name: 'app-collect-pay-page',
        component: () => import('../pages/CollectPayPage.vue'),
        meta: { hasPageToolbar: true, title: 'Pay in', headerTitle: 'Pay in' },
        beforeEnter: guard('payments'),
      },
      {
        path: 'remit',
        name: 'app-remit-pay-page',
        component: () => import('../pages/RemitPayPage.vue'),
        meta: { hasPageToolbar: true, title: 'Remittance', headerTitle: 'Remittance' },
        beforeEnter: guard('payments'),
      },
      {
        path: 'payout',
        name: 'app-payout-pay-page',
        component: () => import('../pages/PayoutPayPage.vue'),
        meta: { hasPageToolbar: true, title: 'Pay out', headerTitle: 'Pay out' },
        beforeEnter: guard('payments'),
      },
      {
        path: ':payId',
        name: 'app-pay-detail-page',
        component: () => import('../pages/PayDetailPage.vue'),
        meta: { hasPageToolbar: true, title: 'Payment', headerTitle: 'Payment' },
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
      {
        path: ':entityType/:entityId',
        name: 'app-cashbook-party-page',
        component: () => import('../pages/CashbookPartyPage.vue'),
        meta: { hasPageToolbar: true, title: 'Cashbook', headerTitle: 'Cashbook' },
        beforeEnter: guard('universal_wallet'),
      },
    ],
  },
];

export default billsPaysRoutes;
