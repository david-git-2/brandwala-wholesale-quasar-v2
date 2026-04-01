import { useAuthStore } from '../stores/authStore'
import type { AuthScope } from '../composables/useOAuthLogin'

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
}: {
  allowedRoles?: AccessRole[]
  loginRouteName: string
  requiredScope?: AuthScope
}) => {
  return (to: { fullPath: string }) => {
    const authStore = useAuthStore()
    const memberRole = authStore.member?.role
    const currentScope = authStore.scope

    if (
      !authStore.isAuthenticated ||
      !authStore.hasAccess ||
      (requiredScope !== undefined && currentScope !== requiredScope) ||
      !memberRole ||
      (allowedRoles !== undefined && !allowedRoles.includes(memberRole))
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
