import type { NavigationGuard, RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const CUSTOMER_OVERVIEW_MODULE_KEYS = ['customer', 'recipient_profile'] as const satisfies readonly ModuleKey[];

const customerOverviewGuard: NavigationGuard = async (to, _from, next) => {
  const authStore = useAuthStore();
  const hasAnyCustomerAccess = CUSTOMER_OVERVIEW_MODULE_KEYS.some((moduleKey) =>
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

  if (hasAnyCustomerAccess) {
    next();
    return;
  }

  const result = await createAccessGuard({
    requiredScope: 'app',
    requiredModule: 'customer',
    loginRoute: (routeTo) => ({ name: 'login', query: { redirect: routeTo.fullPath } }),
  })(to);
  if (result === true) {
    next();
    return;
  }
  if (result === false) {
    next(false);
    return;
  }
  next(result);
};

const customerRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/customers',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-customers',
        component: () => import('../pages/CustomerOverviewPage.vue'),
        beforeEnter: customerOverviewGuard,
      },
      {
        path: 'list',
        name: 'app-customers-list',
        component: () => import('../pages/CustomerHubPage.vue'),
        beforeEnter: createAccessGuard({
          requiredScope: 'app',
          requiredModule: 'customer',
          loginRoute: (to) => ({ name: 'login', query: { redirect: to.fullPath } }),
        }),
      },
      {
        path: 'overview',
        redirect: (to) => {
          const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
          return tenantSlug ? `/${tenantSlug}/app/customers` : '/app/customers';
        },
      },
      {
        path: 'create',
        redirect: (to) => {
          const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
          return tenantSlug ? `/${tenantSlug}/app/customers/list` : '/app/customers/list';
        },
      },
      {
        path: 'create/v2',
        redirect: (to) => {
          const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
          return tenantSlug ? `/${tenantSlug}/app/customers/list` : '/app/customers/list';
        },
      },
      {
        path: 'recipient-profiles',
        name: 'app-global-recipient-profiles',
        component: () =>
          import('../pages/RecipientProfilesPage.vue'),
        beforeEnter: createAccessGuard({
          requiredScope: 'app',
          requiredModule: 'recipient_profile',
          loginRoute: (to) => ({ name: 'login', query: { redirect: to.fullPath } }),
        }),
      },
    ],
  },
];

export default customerRoutes;
