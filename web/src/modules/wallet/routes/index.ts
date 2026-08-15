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

const walletRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/wallet',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-wallet-home-page',
        component: () => import('../pages/WalletHomePage.vue'),
        meta: {
          hasPageToolbar: true,
        },
        beforeEnter: guard('universal_wallet'),
      },
      {
        path: 'company/:tenantId',
        name: 'app-wallet-company-detail',
        component: () => import('../pages/UniversalWalletPage.vue'),
        meta: {
          hasPageToolbar: true,
        },
        beforeEnter: guard('universal_wallet'),
      },
      {
        path: ':walletType',
        name: 'app-wallet-entity-list-page',
        component: () => import('../pages/WalletEntityListPage.vue'),
        meta: {
          hasPageToolbar: true,
        },
        beforeEnter: guard('universal_wallet'),
      },
      {
        path: ':walletType/:entityId',
        name: 'app-universal-wallet-page',
        component: () => import('../pages/UniversalWalletPage.vue'),
        meta: {
          hasPageToolbar: true,
        },
        beforeEnter: guard('universal_wallet'),
      },
    ],
  },
];

export default walletRoutes;
