import { computed } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import {
  getModuleRoutesForScope,
  type InteractiveScope,
  type ModuleAction,
  type ModuleKey,
} from './moduleRegistry'

const NO_ACCESS: readonly ModuleAction[] = []

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
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
  effectiveGrants?: readonly { module_key: string; action: string }[] | null
  isAdmin?: boolean | null
}) => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const tenantHasModule = activeModuleKeys.includes(moduleKey)

  let roleAllowed = false
  if (role === 'superadmin' || isAdmin === true) {
    roleAllowed = true
  } else if (effectiveGrants) {
    roleAllowed = effectiveGrants.some(
      (grant) => grant.module_key === moduleKey && grant.action === action,
    )
  }

  if (
    moduleKey === 'global_shipment' ||
    moduleKey === 'global_stock' ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore()
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null
    if (current && current.parent_id !== null) {
      return false
    }
  }

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
  effectiveGrants,
  isAdmin,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
  effectiveGrants?: readonly { module_key: string; action: string }[] | null
  isAdmin?: boolean | null
}): ModuleAccessResolution => {
  const hasScopeContext = isInteractiveScope(scope)
  const hasTenantContext = hasTenantContextForScope({ scope, tenantId })
  const hasCustomerGroupContext = hasCustomerGroupContextForScope({
    scope,
    customerGroupId,
  })
  const moduleEnabled = activeModuleKeys.includes(moduleKey)

  let roleAllowed = false
  let allowedActions: readonly ModuleAction[] = []
  if (role === 'superadmin' || isAdmin === true) {
    roleAllowed = true
    allowedActions = ['view']
  } else if (effectiveGrants) {
    allowedActions = effectiveGrants
      .filter((grant) => grant.module_key === moduleKey)
      .map((grant) => grant.action as ModuleAction)
    roleAllowed = allowedActions.includes(action)
  } else {
    allowedActions = NO_ACCESS
    roleAllowed = false
  }

  let isBlockedByChildStatus = false
  if (
    moduleKey === 'global_shipment' ||
    moduleKey === 'global_stock' ||
    moduleKey === 'investor_capital' ||
    moduleKey === 'investor_profiles' ||
    moduleKey === 'investor_capital_ledger' ||
    moduleKey === 'investor_shipment_share' ||
    moduleKey === 'investor_portal'
  ) {
    const tenantStore = useTenantStore()
    const current =
      tenantStore.selectedTenant ??
      tenantStore.items.find((tenant) => tenant.id === tenantId) ??
      null
    if (current && current.parent_id !== null) {
      isBlockedByChildStatus = true
    }
  }

  return {
    allowed:
      hasScopeContext &&
      hasTenantContext &&
      hasCustomerGroupContext &&
      moduleEnabled &&
      roleAllowed &&
      !isBlockedByChildStatus,
    hasScopeContext,
    hasTenantContext,
    hasCustomerGroupContext,
    moduleEnabled: moduleEnabled && !isBlockedByChildStatus,
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
  effectiveGrants,
  isAdmin,
}: {
  scope: AuthScope | null
  tenantId: number | null | undefined
  customerGroupId?: number | null | undefined
  role: AccessRole | null | undefined
  activeModuleKeys: readonly string[]
  tenantSlug?: string | null | undefined
  effectiveGrants?: readonly { module_key: string; action: string }[] | null
  isAdmin?: boolean | null
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
      effectiveGrants,
      isAdmin,
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
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
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
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
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
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    })

  return {
    accessibleModuleRoutes,
    getModuleAccess,
    hasModuleAccess,
  }
}

export type { ModuleKey, ModuleAction } from './moduleRegistry'
