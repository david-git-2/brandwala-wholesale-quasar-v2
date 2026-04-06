import { computed } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import {
  getModuleRoutesForScope,
  type InteractiveScope,
  type ModuleAction,
  type ModuleKey,
} from './moduleRegistry'

type ModulePermissionMatrix = Readonly<
  Record<AccessRole, Readonly<Record<ModuleKey, readonly ModuleAction[]>>>
>

const NO_ACCESS: readonly ModuleAction[] = []

const MODULE_PERMISSION_MATRIX: ModulePermissionMatrix = {
  superadmin: {
    order_management: ['view'],
    shipment: ['view'],
    inventory: ['view'],
    product_based_costing: ['view'],
    costing_file: ['view'],
    accounting: ['view'],
    invoice: ['view'],
  },
  admin: {
    order_management: ['view'],
    shipment: ['view'],
    inventory: ['view'],
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    accounting: ['view'],
    invoice: ['view'],
  },
  staff: {
    order_management: ['view'],
    shipment: ['view'],
    inventory: ['view'],
    product_based_costing: NO_ACCESS,
    costing_file: ['view'],
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_admin: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    product_based_costing: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_negotiator: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    product_based_costing: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_staff: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    product_based_costing: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
}

const isInteractiveScope = (
  scope: AuthScope | null,
): scope is InteractiveScope => scope === 'app' || scope === 'shop'

export const hasTenantContextForScope = ({
  scope,
  tenantId,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
}) => {
  if (!isInteractiveScope(scope)) {
    return false
  }

  return typeof tenantId === 'number' && Number.isFinite(tenantId)
}

export const hasCustomerGroupContextForScope = ({
  scope,
  customerGroupId,
}: {
  scope: AuthScope | null
  customerGroupId: number | null | undefined
}) => {
  if (scope !== 'shop') {
    return true
  }

  return typeof customerGroupId === 'number' && Number.isFinite(customerGroupId)
}

export type ModuleAccessResolution = {
  allowed: boolean
  hasScopeContext: boolean
  hasTenantContext: boolean
  hasCustomerGroupContext: boolean
  moduleEnabled: boolean
  roleAllowed: boolean
  allowedActions: readonly ModuleAction[]
}

export const getAllowedModuleActions = (
  role: AccessRole | null | undefined,
  moduleKey: ModuleKey,
) => {
  if (!role) {
    return NO_ACCESS
  }

  return MODULE_PERMISSION_MATRIX[role]?.[moduleKey] ?? NO_ACCESS
}

export const canAccessModule = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
}) => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const tenantHasModule = activeModuleKeys.includes(moduleKey)
  const allowedActions = getAllowedModuleActions(role, moduleKey)
  const roleAllowed = allowedActions.includes(action)

  return (
    hasScopeContext &&
    hasTenantContext &&
    hasCustomerGroupContext &&
    tenantHasModule &&
    roleAllowed
  )
}

export const resolveModuleAccess = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
}): ModuleAccessResolution => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const allowedActions = getAllowedModuleActions(role, moduleKey)
  const moduleEnabled = activeModuleKeys.includes(moduleKey)
  const roleAllowed = allowedActions.includes(action)

  return {
    allowed:
      hasScopeContext &&
      hasTenantContext &&
      hasCustomerGroupContext &&
      moduleEnabled &&
      roleAllowed,
    hasScopeContext,
    hasTenantContext,
    hasCustomerGroupContext,
    moduleEnabled,
    roleAllowed,
    allowedActions,
  }
}

export const getAccessibleModuleRoutes = ({
  scope,
  tenantId,
  customerGroupId,
  role,
  activeModuleKeys,
  tenantSlug,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  activeModuleKeys: readonly string[]
  tenantSlug?: string | null | undefined
}) => {
  if (!isInteractiveScope(scope)) {
    return []
  }

  return getModuleRoutesForScope(scope, { tenantSlug }).filter((routeDefinition) =>
    resolveModuleAccess({
      scope,
      tenantId,
      customerGroupId,
      role,
      moduleKey: routeDefinition.moduleKey,
      activeModuleKeys,
      action: routeDefinition.requiredAction ?? 'view',
    }).allowed,
  )
}

export const useModulePermissions = () => {
  const authStore = useAuthStore()

  const accessibleModuleRoutes = computed(() =>
    getAccessibleModuleRoutes({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      activeModuleKeys: authStore.activeModuleKeys,
      tenantSlug: authStore.tenantSlug,
    }),
  )

  const hasModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
    })

  const getModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    resolveModuleAccess({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
    })

  return {
    accessibleModuleRoutes,
    getModuleAccess,
    hasModuleAccess,
  }
}

export type { ModuleKey, ModuleAction } from './moduleRegistry'
