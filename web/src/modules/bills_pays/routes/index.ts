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
    path: '/:tenantSlug?/app/bills',
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
        meta: { hasPageToolbar: true, title: 'Bill brands', headerTitle: 'Bill brands' },
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
        redirect: (to) => ({
          name: 'app-payments-page',
          params: to.params,
          query: { ...to.query },
        }),
      },
      {
        path: 'remit',
        redirect: (to) => ({
          name: 'app-courier-remit-page',
          params: to.params,
          query: to.query,
        }),
      },
      {
        path: 'courier-remit',
        name: 'app-courier-remit-page',
        component: () => import('../pages/CollectPayPage.vue'),
        meta: { hasPageToolbar: true, title: 'Courier remittance', headerTitle: 'Courier remittance' },
        beforeEnter: guard('payments'),
      },
      {
        path: 'payout',
        redirect: (to) => ({
          name: 'app-payments-page',
          params: to.params,
          query: { ...to.query, desk: 'payout' },
        }),
      },
      {
        path: 'party/:entityType/:entityId',
        name: 'app-payment-profile-page',
        component: () => import('../pages/PaymentProfilePage.vue'),
        meta: { hasPageToolbar: true, title: 'Profile', headerTitle: 'Profile' },
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
    path: '/:tenantSlug?/app/wallet/:pathMatch(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
      const tail =
        typeof to.params.pathMatch === 'string'
          ? `/${to.params.pathMatch}`
          : Array.isArray(to.params.pathMatch)
            ? `/${to.params.pathMatch.join('/')}`
            : '';
      const base = tenantSlug ? `/${tenantSlug}/app/cashbook` : '/app/cashbook';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `${base}${tail}${query}${to.hash ?? ''}`;
    },
  },
  {
    path: '/:tenantSlug?/app/wallet',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
      const base = tenantSlug ? `/${tenantSlug}/app/cashbook` : '/app/cashbook';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `${base}${query}${to.hash ?? ''}`;
    },
  },
  {
    path: '/:tenantSlug?/app/cashbook',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-cashbook-page',
        component: () => import('../pages/CashbookPage.vue'),
        meta: { hasPageToolbar: true, title: 'Cashbook', headerTitle: 'Cashbook' },
        beforeEnter: guard('cashbook'),
      },
      {
        path: ':entityType/:entityId/points',
        name: 'app-cashbook-points-page',
        component: () => import('../pages/CashbookPointsPage.vue'),
        meta: { hasPageToolbar: true, title: 'Locations', headerTitle: 'Locations' },
        beforeEnter: guard('cashbook'),
      },
      {
        path: ':entityType/:entityId',
        name: 'app-cashbook-party-page',
        component: () => import('../pages/CashbookPartyPage.vue'),
        meta: { hasPageToolbar: true, title: 'Cashbook', headerTitle: 'Cashbook' },
        beforeEnter: guard('cashbook'),
      },
    ],
  },
];

export default billsPaysRoutes;
