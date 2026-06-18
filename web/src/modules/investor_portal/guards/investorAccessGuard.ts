import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { RouteLocationRaw } from 'vue-router'

type GuardRoute = {
  fullPath: string
  params?: Record<string, unknown>
}

export const createInvestorAccessGuard = ({
  loginRoute,
}: {
  loginRoute: string
}) => {
  return (to: GuardRoute) => {
    const authStore = useAuthStore()

    const hasInvestorPortal =
      authStore.scope === 'investor' &&
      authStore.isAuthenticated &&
      authStore.activeModuleKeys.includes('investor_portal') &&
      authStore.matchedRole === 'investor_portal'

    if (!hasInvestorPortal) {
      return {
        name: loginRoute,
        query: { redirect: to.fullPath },
      } satisfies RouteLocationRaw
    }

    return true
  }
}
