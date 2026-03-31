import { useAuthStore } from '../stores/authStore'

export type AccessRole = 'superadmin' | 'admin' | 'staff' | 'customer' | 'viewer'

export const createAccessGuard = (
  allowedRoles: AccessRole[],
  loginRouteName: string,
) => {
  return () => {
    const authStore = useAuthStore()
    const memberRole = authStore.member?.role

    if (!authStore.isAuthenticated || !memberRole || !allowedRoles.includes(memberRole)) {
      return { name: loginRouteName }
    }

    return true
  }
}
