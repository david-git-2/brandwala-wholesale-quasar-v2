import { useAuthStore } from '../stores/authStore';
import type { AuthScope } from '../composables/useOAuthLogin';
import {
  canAccessModule,
  type ModuleAction,
  type ModuleKey,
} from 'src/modules/navigation/modulePermissions';
import type { LocationQueryRaw, RouteLocationRaw } from 'vue-router';

type GuardRoute = {
  name?: string | symbol | null | undefined;
  fullPath: string;
  params?: Record<string, unknown> | undefined;
  query?: LocationQueryRaw | undefined;
};

export type AccessRole =
  | 'superadmin'
  | 'admin'
  | 'staff'
  | 'viewer'
  | 'customer_admin'
  | 'customer_negotiator'
  | 'customer_staff'
  | 'investor_portal';

export const mapShopRoleToAccessRole = (role: string): AccessRole | null => {
  switch (role) {
    case 'admin':
      return 'customer_admin';
    case 'negotiator':
      return 'customer_negotiator';
    case 'staff':
      return 'customer_staff';
    case 'customer_admin':
    case 'customer_negotiator':
    case 'customer_staff':
      return role;
    default:
      return null;
  }
};

export const createAccessGuard = ({
  allowedRoles,
  loginRoute,
  requiredScope,
  requireTenantContext,
  requiredModule,
  requiredModuleAction,
  validateAccess,
}: {
  allowedRoles?: readonly AccessRole[];
  loginRoute: string | ((to: GuardRoute) => RouteLocationRaw);
  requiredScope?: AuthScope;
  requireTenantContext?: boolean;
  requiredModule?: ModuleKey;
  requiredModuleAction?: ModuleAction;
  validateAccess?: (context: {
    authStore: ReturnType<typeof useAuthStore>;
    to: GuardRoute;
  }) => boolean | RouteLocationRaw;
}) => {
  return async (to: GuardRoute) => {
    const authStore = useAuthStore();

    if (authStore.isAuthenticated && authStore.tenantId) {
      await authStore.checkFreshness();
    }

    const memberRole = authStore.member?.role;
    const currentScope = authStore.scope;
    const hasTenantContext = authStore.tenantId !== null;
    const hasRequiredModuleAccess =
      requiredModule === undefined
        ? true
        : canAccessModule({
            scope: authStore.scope,
            tenantId: authStore.tenantId,
            customerGroupId: authStore.customerGroupId,
            role: authStore.matchedRole,
            moduleKey: requiredModule,
            activeModuleKeys: authStore.activeModuleKeys,
            action: requiredModuleAction ?? 'view',
            effectiveGrants: authStore.access?.effectiveGrants,
            isAdmin: authStore.access?.isAdmin,
          });

    if (
      !authStore.isAuthenticated ||
      !authStore.hasAccess ||
      (requiredScope !== undefined && currentScope !== requiredScope) ||
      (requireTenantContext === true && !hasTenantContext) ||
      !memberRole ||
      (allowedRoles !== undefined && !allowedRoles.includes(memberRole))
    ) {
      if (typeof loginRoute === 'function') {
        return loginRoute(to);
      }

      return {
        name: loginRoute,
        query: {
          redirect: to.fullPath,
        },
      };
    }

    if (!hasRequiredModuleAccess) {
      const tenantSlug = authStore.tenantSlug;

      if (currentScope === 'shop') {
        return tenantSlug ? `/${tenantSlug}/shop/dashboard` : '/shop/dashboard';
      }

      if (requiredModule === 'global_shipment' || requiredModule === 'global_stock') {
        return tenantSlug
          ? `/${tenantSlug}/app/procurement/tenant-stock`
          : '/app/procurement/tenant-stock';
      }

      return tenantSlug ? `/${tenantSlug}/app/dashboard` : '/app/dashboard';
    }

    if (validateAccess) {
      const validationResult = validateAccess({
        authStore,
        to,
      });

      if (validationResult !== true) {
        return validationResult;
      }
    }

    return true;
  };
};
