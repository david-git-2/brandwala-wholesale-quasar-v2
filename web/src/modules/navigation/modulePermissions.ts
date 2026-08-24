import { computed } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import {
  resolveTenantHierarchyKind,
  type TenantHierarchyKind,
} from 'src/modules/tenant/utils/tenantHierarchy';
import type { AccessRole } from 'src/modules/auth/guards/accessGuard';
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';
import {
  buildModuleRoutePath,
  getModuleDefinition,
  getModuleRoutesForScope,
  type InteractiveScope,
  type ModuleAction,
  type ModuleKey,
} from './moduleRegistry';

const PROCUREMENT_HUB_MODULE_KEYS: readonly ModuleKey[] = [
  'procurement_demand',
  'global_shipment',
  'global_stock',
  'global_stock_movement',
  'global_stock_location',
  'cargo_company',
  'shipment_progress_settings',
  'inventory',
];

const REFERENCE_HUB_MODULE_KEYS: readonly ModuleKey[] = [
  'global_reference_currency',
  'global_reference_market',
  'global_reference_payment_method',
  'global_reference_unit_of_measure',
];

type ModuleHubConfig = {
  routeSegment: string;
  anchorModuleKey: ModuleKey;
  hubModuleKeys: readonly ModuleKey[];
};

const MODULE_HUB_CONFIGS: readonly ModuleHubConfig[] = [
  {
    routeSegment: 'procurement',
    anchorModuleKey: 'procurement_stock',
    hubModuleKeys: PROCUREMENT_HUB_MODULE_KEYS,
  },
  {
    routeSegment: 'reference',
    anchorModuleKey: 'global_reference_currency',
    hubModuleKeys: REFERENCE_HUB_MODULE_KEYS,
  },
];

const isProcurementHubModuleKey = (moduleKey: ModuleKey): boolean =>
  (PROCUREMENT_HUB_MODULE_KEYS as readonly ModuleKey[]).includes(moduleKey);

const isTenantModuleActive = (
  moduleKey: ModuleKey,
  activeModuleKeys: readonly string[],
): boolean => {
  if (activeModuleKeys.includes(moduleKey)) {
    return true;
  }

  if (moduleKey === 'procurement_demand') {
    return activeModuleKeys.includes('global_shipment');
  }

  if (moduleKey === 'procurement_stock') {
    return PROCUREMENT_HUB_MODULE_KEYS.some((key) => activeModuleKeys.includes(key));
  }

  return false;
};

const hasModuleRoleGrant = ({
  moduleKey,
  action,
  role,
  effectiveGrants,
  isAdmin,
}: {
  moduleKey: ModuleKey;
  action: ModuleAction;
  role: AccessRole | null | undefined;
  effectiveGrants?: readonly { module_key: string; action: string }[] | null | undefined;
  isAdmin?: boolean | null | undefined;
}): boolean => {
  if (role === 'superadmin' || isAdmin === true) {
    return true;
  }

  if (!effectiveGrants) {
    return false;
  }

  if (
    effectiveGrants.some((grant) => grant.module_key === moduleKey && grant.action === action)
  ) {
    return true;
  }

  if (moduleKey === 'procurement_demand') {
    return effectiveGrants.some(
      (grant) => grant.module_key === 'global_shipment' && grant.action === action,
    );
  }

  if (moduleKey === 'procurement_stock') {
    return effectiveGrants.some(
      (grant) => grant.module_key === 'global_shipment' && grant.action === action,
    );
  }

  return false;
};

const NO_ACCESS: readonly ModuleAction[] = [];

const SALES_CHILD_CATALOG_MODULES: ReadonlySet<ModuleKey> = new Set([
  'billing_profile',
  'recipient_profile',
  'invoice_brand',
]);

const isShopOrderFamilyModule = (moduleKey: ModuleKey): boolean =>
  moduleKey === 'shop_order' || getModuleDefinition(moduleKey)?.parentModuleKey === 'shop_order';

const isBlockedOnParentCompany = (
  moduleKey: ModuleKey,
  tenantId: number | null | undefined,
): boolean => {
  if (!SALES_CHILD_CATALOG_MODULES.has(moduleKey) && !isShopOrderFamilyModule(moduleKey)) {
    return false;
  }

  return resolveWorkspaceTenantKind(tenantId) === 'parent';
};

const resolveWorkspaceTenantKind = (
  tenantId: number | null | undefined,
): TenantHierarchyKind => {
  const tenantStore = useTenantStore();
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === tenantId) ??
    tenantStore.availableAdminTenants.find((tenant) => tenant.id === tenantId) ??
    null;
  return resolveTenantHierarchyKind(current, [
    ...tenantStore.availableAdminTenants,
    ...tenantStore.items,
    ...tenantStore.hierarchyChildRefs,
  ]);
};

const isInteractiveScope = (scope: AuthScope | null): scope is InteractiveScope =>
  scope === 'app' || scope === 'shop';

export const hasTenantContextForScope = ({
  scope,
  tenantId,
}: {
  scope: AuthScope | null;
  tenantId: number | null | undefined;
}) => {
  if (!isInteractiveScope(scope)) {
    return false;
  }

  return typeof tenantId === 'number' && Number.isFinite(tenantId);
};

export const hasCustomerGroupContextForScope = ({
  scope,
  customerGroupId,
}: {
  scope: AuthScope | null;
  customerGroupId: number | null | undefined;
}) => {
  if (scope !== 'shop') {
    return true;
  }

  return typeof customerGroupId === 'number' && Number.isFinite(customerGroupId);
};

export type ModuleAccessResolution = {
  allowed: boolean;
  hasScopeContext: boolean;
  hasTenantContext: boolean;
  hasCustomerGroupContext: boolean;
  moduleEnabled: boolean;
  roleAllowed: boolean;
  allowedActions: readonly ModuleAction[];
};

export const canAccessModule = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
  effectiveGrants,
  isAdmin,
}: {
  scope: AuthScope | null;
  tenantId: number | null | undefined;
  customerGroupId?: number | null | undefined;
  role: AccessRole | null | undefined;
  moduleKey: ModuleKey;
  activeModuleKeys: readonly string[];
  action?: ModuleAction;
  effectiveGrants?: readonly { module_key: string; action: string }[] | null | undefined;
  isAdmin?: boolean | null | undefined;
}) => {
  const hasScopeContext = isInteractiveScope(scope);
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId });
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  });
  const tenantHasModule = isTenantModuleActive(moduleKey, activeModuleKeys);

  const roleAllowed = hasModuleRoleGrant({
    moduleKey,
    action,
    role,
    effectiveGrants,
    isAdmin,
  });

  if (
    isProcurementHubModuleKey(moduleKey) ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore();
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null;
    if (current && current.parent_id !== null) {
      return false;
    }
  }

  // Stock (inventory) is child-tenant only — hide on parent / standalone roots
  if (moduleKey === 'inventory') {
    const tenantStore = useTenantStore();
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null;
    if (!current || current.parent_id === null) {
      return false;
    }
  }

  // Billing catalogs and shop storefronts belong to the issuing child / standalone.
  if (isBlockedOnParentCompany(moduleKey, tenantId)) {
    return false;
  }

  return (
    hasScopeContext && hasTenantContext && hasCustomerGroupContext && tenantHasModule && roleAllowed
  );
};

export const resolveModuleAccess = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
  effectiveGrants,
  isAdmin,
}: {
  scope: AuthScope | null;
  tenantId: number | null | undefined;
  customerGroupId?: number | null | undefined;
  role: AccessRole | null | undefined;
  moduleKey: ModuleKey;
  activeModuleKeys: readonly string[];
  action?: ModuleAction;
  effectiveGrants?: readonly { module_key: string; action: string }[] | null | undefined;
  isAdmin?: boolean | null | undefined;
}): ModuleAccessResolution => {
  const hasScopeContext = isInteractiveScope(scope);
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId });
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  });
  const moduleEnabled = isTenantModuleActive(moduleKey, activeModuleKeys);

  let roleAllowed = false;
  let allowedActions: readonly ModuleAction[] = [];
  if (role === 'superadmin' || isAdmin === true) {
    roleAllowed = true;
    allowedActions = ['view'];
  } else if (effectiveGrants) {
    allowedActions = effectiveGrants
      .filter((grant) => grant.module_key === moduleKey)
      .map((grant) => grant.action as ModuleAction);
    roleAllowed = hasModuleRoleGrant({
      moduleKey,
      action,
      role,
      effectiveGrants,
      isAdmin,
    });
    if (
      moduleKey === 'procurement_demand' &&
      allowedActions.length === 0 &&
      effectiveGrants.some((grant) => grant.module_key === 'global_shipment')
    ) {
      allowedActions = effectiveGrants
        .filter((grant) => grant.module_key === 'global_shipment')
        .map((grant) => grant.action as ModuleAction);
    }
  } else {
    allowedActions = NO_ACCESS;
    roleAllowed = false;
  }

  let isBlockedByChildStatus = false;
  if (
    isProcurementHubModuleKey(moduleKey) ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore();
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null;
    if (current && current.parent_id !== null) {
      isBlockedByChildStatus = true;
    }
  }

  let isBlockedByParentStatus = false;
  if (moduleKey === 'inventory') {
    const tenantStore = useTenantStore();
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null;
    if (!current || current.parent_id === null) {
      isBlockedByParentStatus = true;
    }
  }

  if (isBlockedOnParentCompany(moduleKey, tenantId)) {
    isBlockedByParentStatus = true;
  }

  return {
    allowed:
      hasScopeContext &&
      hasTenantContext &&
      hasCustomerGroupContext &&
      moduleEnabled &&
      roleAllowed &&
      !isBlockedByChildStatus &&
      !isBlockedByParentStatus,
    hasScopeContext,
    hasTenantContext,
    hasCustomerGroupContext,
    moduleEnabled: moduleEnabled && !isBlockedByChildStatus && !isBlockedByParentStatus,
    roleAllowed,
    allowedActions,
  };
};

export const getAccessibleModuleRoutes = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  activeModuleKeys,
  tenantSlug,
  effectiveGrants,
  isAdmin,
}: {
  scope: AuthScope | null;
  tenantId: number | null | undefined;
  customerGroupId?: number | null | undefined;
  role: AccessRole | null | undefined;
  activeModuleKeys: readonly string[];
  tenantSlug?: string | null | undefined;
  effectiveGrants?: readonly { module_key: string; action: string }[] | null | undefined;
  isAdmin?: boolean | null | undefined;
}) => {
  if (!isInteractiveScope(scope)) {
    return [];
  }

  const accessibleRoutes = getModuleRoutesForScope(scope, { tenantSlug }).filter(
    (routeDefinition) =>
      resolveModuleAccess({
        scope,
        tenantId,
        customerGroupId,
        role,
        moduleKey: routeDefinition.moduleKey,
        activeModuleKeys,
        action: routeDefinition.requiredAction ?? 'view',
        effectiveGrants,
        isAdmin,
      }).allowed,
  );

  if (scope !== 'app') {
    return accessibleRoutes;
  }

  const accessContext = {
    scope,
    tenantId,
    customerGroupId,
    role,
    activeModuleKeys,
    effectiveGrants,
    isAdmin,
  };

  let routes = [...accessibleRoutes];

  for (const hubConfig of MODULE_HUB_CONFIGS) {
    const hubPath = buildModuleRoutePath({
      scope: 'app',
      routeSegment: hubConfig.routeSegment,
      tenantSlug,
    });

    if (routes.some((route) => route.to === hubPath)) {
      continue;
    }

    const hasAnyHubAccess = hubConfig.hubModuleKeys.some((moduleKey) =>
      resolveModuleAccess({
        ...accessContext,
        moduleKey,
        action: 'view',
      }).allowed,
    );

    if (!hasAnyHubAccess) {
      continue;
    }

    const hubDefinition = getModuleDefinition(hubConfig.anchorModuleKey);
    const hubRoute = hubDefinition.routes.find((routeDefinition) => routeDefinition.scope === 'app');

    if (!hubRoute) {
      continue;
    }

    routes.push({
      moduleKey: hubConfig.anchorModuleKey,
      moduleName: hubDefinition.name,
      to: hubPath,
      ...hubRoute,
    });
  }

  return routes.sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: 'base' }));
};

export const useModulePermissions = () => {
  const authStore = useAuthStore();

  const accessibleModuleRoutes = computed(() =>
    getAccessibleModuleRoutes({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      activeModuleKeys: authStore.activeModuleKeys,
      tenantSlug: authStore.tenantSlug,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    }),
  );

  const hasModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    });

  const getModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    resolveModuleAccess({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    });

  return {
    accessibleModuleRoutes,
    getModuleAccess,
    hasModuleAccess,
  };
};

export type { ModuleKey, ModuleAction } from './moduleRegistry';
