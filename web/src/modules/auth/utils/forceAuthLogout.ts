import type { Router } from 'vue-router'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from '../stores/authStore'
import {
  getAppRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

let appRouter: Router | null = null
let isLoggingOut = false
let sessionRefreshInFlight: Promise<boolean> | null = null

export function setAuthSessionRouter(router: Router) {
  appRouter = router
}

export async function tryRefreshSession(): Promise<boolean> {
  if (sessionRefreshInFlight) {
    return sessionRefreshInFlight
  }

  sessionRefreshInFlight = (async () => {
    const { data: { session }, error } = await supabase.auth.refreshSession()
    return Boolean(session) && !error
  })().finally(() => {
    sessionRefreshInFlight = null
  })

  return sessionRefreshInFlight
}

export async function handleUnauthorizedResponse() {
  if (isLoggingOut) return
  isLoggingOut = true

  try {
    const router = appRouter
    if (!router) {
      console.warn('[auth] handleUnauthorizedResponse called before router was initialized')
      isLoggingOut = false
      return
    }

    const currentRoute = router.currentRoute.value
    const routeName = (currentRoute.name as string) || ''

    const loginRouteNames = [
      'admin-login-page',
      'customer-login-page',
      'superadmin-login-page',
      'investor-login-page',
      'auth-callback-page',
      'auth-callback'
    ]
    if (loginRouteNames.includes(routeName) || currentRoute.path.includes('/auth/callback')) {
      isLoggingOut = false
      return
    }

    const authStore = useAuthStore()
    let scope = authStore.scope
    const tenantSlug = authStore.tenantSlug ?? getTenantSlugFromRoute(currentRoute)

    if (!scope) {
      const path = currentRoute.path
      if (path.startsWith('/platform')) {
        scope = 'platform'
      } else if (path.startsWith('/shop')) {
        scope = 'shop'
      } else if (path.startsWith('/investor')) {
        scope = 'investor'
      } else {
        scope = 'app'
      }
    }

    authStore.clearAccess()
    await supabase.auth.signOut()

    const loginError = 'session_expired'

    if (scope === 'platform') {
      await router.replace({
        name: 'superadmin-login-page',
        query: { login_error: loginError }
      })
    } else if (scope === 'shop') {
      const loginRouteLocation = getShopLoginRouteLocation(currentRoute, {
        login_error: loginError
      })
      await router.replace(loginRouteLocation)
    } else if (scope === 'investor') {
      await router.replace({
        name: 'investor-login-page',
        params: tenantSlug ? { tenantSlug } : {},
        query: { login_error: loginError }
      })
    } else {
      const loginRouteLocation = getAppRouteLocation(
        {
          name: 'admin-login-page',
          params: tenantSlug ? { tenantSlug } : {},
          query: {}
        },
        tenantSlug
      )

      await router.replace({
        ...(typeof loginRouteLocation === 'string' ? { path: loginRouteLocation } : loginRouteLocation),
        query: {
          login_error: loginError
        }
      })
    }
  } catch (err) {
    console.error('[auth] Error in forceAuthLogout:', err)
  } finally {
    isLoggingOut = false
  }
}
