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
