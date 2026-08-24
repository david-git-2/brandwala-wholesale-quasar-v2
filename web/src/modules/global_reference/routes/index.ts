import type { NavigationGuard, RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const platformGuard = createAccessGuard({
  loginRoute: 'superadmin-login-page',
  requiredScope: 'platform',
  allowedRoles: ['superadmin'],
});

const appGuard = (
  requiredModule:
    | 'global_reference_currency'
    | 'global_reference_market'
    | 'global_reference_payment_method'
    | 'global_reference_unit_of_measure',
) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    allowedRoles: ['admin', 'staff'],
    requireTenantContext: true,
    requiredModule,
  });

const REFERENCE_OVERVIEW_MODULE_KEYS = [
  'global_reference_currency',
  'global_reference_market',
  'global_reference_payment_method',
  'global_reference_unit_of_measure',
] as const satisfies readonly ModuleKey[];

const referenceOverviewGuard: NavigationGuard = (to, from, next) => {
  const authStore = useAuthStore();
  const hasAnyReferenceAccess = REFERENCE_OVERVIEW_MODULE_KEYS.some((moduleKey) =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    }),
  );

  if (hasAnyReferenceAccess) {
    next();
    return;
  }

  return appGuard('global_reference_currency')(to, from, next);
};

const globalReferenceRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/markets',
    redirect: '/platform/reference/markets',
  },
  {
    path: '/platform/reference',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: platformGuard,
    children: [
      {
        path: '',
        name: 'platform-reference-hub',
        component: () => import('../pages/ReferenceHubPage.vue'),
      },
      {
        path: 'markets',
        name: 'platform-reference-markets',
        component: () => import('../pages/MarketsPage.vue'),
      },
      {
        path: 'currencies',
        name: 'platform-reference-currencies',
        component: () => import('../pages/CurrenciesPage.vue'),
      },
      {
        path: 'payment-methods',
        name: 'platform-reference-payment-methods',
        component: () => import('../pages/PaymentMethodsPage.vue'),
      },
      {
        path: 'units',
        name: 'platform-reference-units',
        component: () => import('../pages/UnitsOfMeasurePage.vue'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/currencies',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null;
      return tenantSlug ? `/${tenantSlug}/app/reference/currencies` : '/app/reference/currencies';
    },
  },
  {
    path: '/:tenantSlug?/app/reference',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-reference-overview',
        component: () => import('../pages/AppReferenceOverviewPage.vue'),
        beforeEnter: referenceOverviewGuard,
        meta: { title: 'Reference', headerTitle: 'Reference' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/currencies',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_currency'),
    children: [
      {
        path: '',
        name: 'app-reference-currencies',
        component: () => import('../pages/AppCurrenciesPage.vue'),
        meta: { title: 'Currencies', headerTitle: 'Currencies' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/markets',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_market'),
    children: [
      {
        path: '',
        name: 'app-reference-markets',
        component: () => import('../pages/AppMarketsPage.vue'),
        meta: { title: 'Markets', headerTitle: 'Markets' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/payment-methods',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_payment_method'),
    children: [
      {
        path: '',
        name: 'app-reference-payment-methods',
        component: () => import('../pages/AppPaymentMethodsPage.vue'),
        meta: { title: 'Payment Methods', headerTitle: 'Payment Methods' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/units',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_unit_of_measure'),
    children: [
      {
        path: '',
        name: 'app-reference-units',
        component: () => import('../pages/AppUnitsPage.vue'),
        meta: { title: 'Units of Measure', headerTitle: 'Units of Measure' },
      },
    ],
  },
];

export default globalReferenceRoutes;
