import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from '../stores/authStore'

export type AuthScope = 'platform' | 'app' | 'shop'

const scopeConfig: Record<
  AuthScope,
  {
    title: string
    homeRouteName: string
    loginRouteName: string
    loginPath: string
  }
> = {
  platform: {
    title: 'Platform Login',
    homeRouteName: 'superadmin-dashboard',
    loginRouteName: 'superadmin-login-page',
    loginPath: '/auth/platform/login',
  },
  app: {
    title: 'Admin Login',
    homeRouteName: 'admin-dashboard',
    loginRouteName: 'login-page',
    loginPath: '/auth/add/login',
  },
  shop: {
    title: 'Shop Login',
    homeRouteName: 'customer-dashboard',
    loginRouteName: 'customer-login-page',
    loginPath: '/auth/shop/login',
  },
}

export function useOAuthLogin(scope?: AuthScope) {
  const route = useRoute()
  const router = useRouter()
  const authStore = useAuthStore()
  const isLoading = ref(false)
  const resolvedScope =
    scope ?? (((route.meta as { authScope?: AuthScope }).authScope) ?? 'app')
  const currentScope = scopeConfig[resolvedScope]

  const logAuthContext = (message: string, payload?: unknown) => {
    console.log(`[auth:${resolvedScope}] ${message}`, payload ?? '')
  }

  const sendBackToLogin = async (message: string, payload?: unknown) => {
    logAuthContext(message, payload)
    authStore.clearAccess()
    await supabase.auth.signOut()
    await router.replace({
      name: currentScope.loginRouteName,
      query: {
        login_error: 'no_membership',
      },
    })
  }

  const processLoginResult = async () => {
    const { data: sessionData } = await supabase.auth.getSession()
    const session = sessionData.session

    if (!session?.user) {
      await sendBackToLogin('No OAuth session yet on this page', {
        path: route.path,
        fullPath: route.fullPath,
        url: window.location.href,
      })
      return false
    }

    const userEmail = session.user.email?.trim().toLowerCase() ?? ''

    if (!userEmail) {
      await sendBackToLogin('OAuth session did not include an email address', {
        userId: session.user.id,
        scope: resolvedScope,
      })
      return false
    }

    logAuthContext('Current route', {
      path: route.path,
      fullPath: route.fullPath,
      url: window.location.href,
      email: userEmail,
    })

    const { data, error } = await supabase.rpc('check_login_membership', {
      p_email: userEmail,
      p_scope: resolvedScope,
    })

    if (error) {
      console.error(`[auth:${resolvedScope}] Login access check failed`, error)
      await sendBackToLogin('Login access check failed', error)
      return false
    }

    const result = Array.isArray(data) ? data[0] : data

    if (
      result?.has_match &&
      result.member_id !== null &&
      result.member_email &&
      result.member_created_at &&
      result.member_updated_at &&
      result.matched_role
    ) {
      logAuthContext('Membership match found', result)
      authStore.saveAccess({
        scope: resolvedScope,
        matchedRole: result.matched_role,
        user: {
          id: session.user.id,
          email: userEmail,
          fullName:
            (session.user.user_metadata?.full_name as string | undefined) ??
            (session.user.user_metadata?.name as string | undefined) ??
            null,
          avatarUrl:
            (session.user.user_metadata?.avatar_url as string | undefined) ??
            null,
          provider: session.user.app_metadata?.provider ?? null,
        },
        member: {
          id: result.member_id,
          email: result.member_email?.trim().toLowerCase() ?? userEmail,
          role: result.matched_role,
          tenantId: result.member_tenant_id ?? null,
          isActive: Boolean(result.member_is_active),
          createdAt: result.member_created_at,
          updatedAt: result.member_updated_at,
        },
        savedAt: new Date().toISOString(),
      })
      await router.replace({ name: currentScope.homeRouteName })
      return true
    }

    await sendBackToLogin('No matching membership found for this route', result)
    return false
  }

  const handleGoogleLogin = async () => {
    isLoading.value = true

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/#/auth/callback?scope=${resolvedScope}`,
      },
    })

    isLoading.value = false

    if (error) {
      console.error(`[auth:${resolvedScope}] Google OAuth error`, error)
      return
    }

    logAuthContext('Google OAuth started', data)
  }

  return {
    handleGoogleLogin,
    isLoading,
    processLoginResult,
    title: currentScope.title,
  }
}
