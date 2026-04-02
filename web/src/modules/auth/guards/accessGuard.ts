import { useAuthStore } from '../stores/authStore'
import type { AuthScope } from '../composables/useOAuthLogin'
import {
  canAccessModule,
  type ModuleAction,
  type ModuleKey,
} from 'src/modules/navigation/modulePermissions'
import type { RouteLocationRaw } from 'vue-router'

export type AccessRole =
  | 'superadmin'
  | 'admin'
  | 'staff'
  | 'customer_admin'
  | 'customer_negotiator'
  | 'customer_staff'

export const createAccessGuard = ({
  allowedRoles,
  loginRoute,
  requiredScope,
  requiredModule,
  requiredModuleAction,
  validateAccess,
}: {
  allowedRoles?: AccessRole[]
  loginRoute: string | ((to: { fullPath: string; params?: Record<string, unknown>; query?: Record<string, unknown> }) => RouteLocationRaw)
  requiredScope?: AuthScope
  requiredModule?: ModuleKey
  requiredModuleAction?: ModuleAction
  validateAccess?: (context: {
    authStore: ReturnType<typeof useAuthStore>
    to: { fullPath: string; params?: Record<string, unknown>; query?: Record<string, unknown> }
  }) => boolean | RouteLocationRaw
}) => {
  return (to: { fullPath: string; params?: Record<string, unknown>; query?: Record<string, unknown> }) => {
    const authStore = useAuthStore()
    const memberRole = authStore.member?.role
    const currentScope = authStore.scope
    const hasRequiredModuleAccess =
      requiredModule === undefined
        ? true
        : canAccessModule({
            role: memberRole,
            moduleKey: requiredModule,
            activeModuleKeys: authStore.activeModuleKeys,
            action: requiredModuleAction ?? 'view',
          })

    if (
      !authStore.isAuthenticated ||
      !authStore.hasAccess ||
      (requiredScope !== undefined && currentScope !== requiredScope) ||
      !memberRole ||
      (allowedRoles !== undefined && !allowedRoles.includes(memberRole)) ||
      !hasRequiredModuleAccess
    ) {
      if (typeof loginRoute === 'function') {
        return loginRoute(to)
      }

      return {
        name: loginRoute,
        query: {
          redirect: to.fullPath,
        },
      }
    }

    if (validateAccess) {
      const validationResult = validateAccess({
        authStore,
        to,
      })

      if (validationResult !== true) {
        return validationResult
      }
    }

    return true
  }
}
