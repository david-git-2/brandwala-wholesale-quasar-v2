import { computed } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { AccessRole } from 'src/modules/auth/guards/accessGuard'
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'
import {
  getModuleRoutesForScope,
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
    shop_costing_file: ['view'],
    costing_file: ['view'],
    accounting: ['view'],
    invoice: ['view'],
  },
  admin: {
    order_management: ['view'],
    shipment: ['view'],
    inventory: ['view'],
    shop_costing_file: NO_ACCESS,
    costing_file: ['view'],
    accounting: ['view'],
    invoice: ['view'],
  },
  staff: {
    order_management: ['view'],
    shipment: ['view'],
    inventory: ['view'],
    shop_costing_file: NO_ACCESS,
    costing_file: ['view'],
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_admin: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    shop_costing_file: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_negotiator: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    shop_costing_file: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
  customer_staff: {
    order_management: ['view'],
    shipment: NO_ACCESS,
    inventory: NO_ACCESS,
    shop_costing_file: ['view'],
    costing_file: NO_ACCESS,
    accounting: NO_ACCESS,
    invoice: ['view'],
  },
}

const isInteractiveScope = (
  scope: AuthScope | null,
): scope is Extract<AuthScope, 'app' | 'shop'> => scope === 'app' || scope === 'shop'

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
  role,
  moduleKey,
  activeModuleKeys,
  action = 'view',
}: {
  role: AccessRole | null | undefined
  moduleKey: ModuleKey
  activeModuleKeys: readonly string[]
  action?: ModuleAction
}) => {
  const tenantHasModule = activeModuleKeys.includes(moduleKey)
  const allowedActions = getAllowedModuleActions(role, moduleKey)

  return tenantHasModule && allowedActions.includes(action)
}

export const getAccessibleModuleRoutes = ({
  scope,
  role,
  activeModuleKeys,
}: {
  scope: AuthScope | null
  role: AccessRole | null | undefined
  activeModuleKeys: readonly string[]
}) => {
  if (!isInteractiveScope(scope)) {
    return []
  }

  return getModuleRoutesForScope(scope).filter((routeDefinition) =>
    canAccessModule({
      role,
      moduleKey: routeDefinition.moduleKey,
      activeModuleKeys,
      action: routeDefinition.requiredAction ?? 'view',
    }),
  )
}

export const useModulePermissions = () => {
  const authStore = useAuthStore()

  const accessibleModuleRoutes = computed(() =>
    getAccessibleModuleRoutes({
      scope: authStore.scope,
      role: authStore.matchedRole,
      activeModuleKeys: authStore.activeModuleKeys,
    }),
  )

  const hasModuleAccess = (moduleKey: ModuleKey, action: ModuleAction = 'view') =>
    canAccessModule({
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      action,
    })

  return {
    accessibleModuleRoutes,
    hasModuleAccess,
  }
}

export type { ModuleKey, ModuleAction } from './moduleRegistry'
