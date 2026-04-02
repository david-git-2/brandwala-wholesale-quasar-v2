import { useAuthStore } from '../stores/authStore'
import type { AuthScope } from '../composables/useOAuthLogin'
import {
  canAccessModule,
  type ModuleAction,
  type ModuleKey,
} from 'src/modules/navigation/modulePermissions'

export type AccessRole =
  | 'superadmin'
  | 'admin'
  | 'staff'
  | 'customer'
  | 'viewer'
  | 'customer_admin'
  | 'customer_negotiator'
  | 'customer_staff'

export const createAccessGuard = ({
  allowedRoles,
  loginRouteName,
  requiredScope,
  requiredModule,
  requiredModuleAction,
}: {
  allowedRoles?: AccessRole[]
  loginRouteName: string
  requiredScope?: AuthScope
  requiredModule?: ModuleKey
  requiredModuleAction?: ModuleAction
}) => {
  return (to: { fullPath: string }) => {
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
      return {
        name: loginRouteName,
        query: {
          redirect: to.fullPath,
        },
      }
    }

    return true
  }
}
