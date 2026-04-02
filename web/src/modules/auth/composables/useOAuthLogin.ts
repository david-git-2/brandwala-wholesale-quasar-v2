import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import type { AccessRole } from '../guards/accessGuard'
import {
  useAuthStore,
  type AuthAccessSnapshot,
  type AuthCustomerGroupSnapshot,
  type AuthTenantSnapshot,
  type AuthUserSnapshot,
} from '../stores/authStore'

export type AuthScope = 'platform' | 'app' | 'shop'

const scopeConfig: Record<
  AuthScope,
  {
    homeRouteName: string
    loginRouteName: string
  }
> = {
  platform: {
    homeRouteName: 'superadmin-dashboard',
    loginRouteName: 'superadmin-login-page',
  },
  app: {
    homeRouteName: 'admin-dashboard',
    loginRouteName: 'admin-login-page',
  },
  shop: {
    homeRouteName: 'customer-dashboard',
    loginRouteName: 'customer-login-page',
  },
}

const mapShopRoleToAccessRole = (role: string): AccessRole | null => {
  switch (role) {
    case 'admin':
      return 'customer_admin'
    case 'negotiator':
      return 'customer_negotiator'
    case 'staff':
      return 'customer_staff'
    default:
      return null
  }
}

const normalizeModuleKeys = (moduleKeys: string[] | null | undefined) =>
  Array.isArray(moduleKeys)
    ? moduleKeys
        .map((moduleKey) => moduleKey?.trim())
        .filter((moduleKey): moduleKey is string => Boolean(moduleKey))
    : []

const normalizeCallbackBaseUrl = (value: string | undefined) =>
  value?.trim().replace(/\/+$/, '') || null

const getOAuthCallbackBaseUrl = () => {
  const localUrl = normalizeCallbackBaseUrl(import.meta.env.VITE_LOCAL_APP_URL)
  const productionUrl = normalizeCallbackBaseUrl(
    import.meta.env.VITE_PRODUCTION_APP_URL,
  )

  if (import.meta.env.DEV) {
    return localUrl ?? window.location.origin
  }

  return productionUrl ?? window.location.origin
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

  const buildUserSnapshot = (
    session: NonNullable<
      Awaited<ReturnType<typeof supabase.auth.getSession>>['data']['session']
    >,
    userEmail: string,
  ): AuthUserSnapshot => ({
    id: session.user.id,
    email: userEmail,
    fullName:
      (session.user.user_metadata?.full_name as string | undefined) ??
      (session.user.user_metadata?.name as string | undefined) ??
      null,
    avatarUrl:
      (session.user.user_metadata?.avatar_url as string | undefined) ?? null,
    provider: session.user.app_metadata?.provider ?? null,
  })

  const saveAndRedirect = async (
    payload: Omit<AuthAccessSnapshot, 'savedAt'>,
  ) => {
    authStore.saveAccess({
      ...payload,
      savedAt: new Date().toISOString(),
    })
    await router.replace({ name: currentScope.homeRouteName })
  }

  const processPlatformLogin = async (
    userEmail: string,
    user: AuthUserSnapshot,
  ) => {
    const { data, error } = await supabase.rpc('check_login_membership', {
      p_email: userEmail,
      p_scope: 'platform',
    })

    if (error) {
      console.error('[auth:platform] Login access check failed', error)
      await sendBackToLogin('Login access check failed', error)
      return false
    }

    const result = Array.isArray(data) ? data[0] : data

    if (
      !result?.has_match ||
      result.member_id === null ||
      !result.member_email ||
      !result.matched_role
    ) {
      await sendBackToLogin('No matching membership found for this route', result)
      return false
    }

    logAuthContext('Platform membership match found', result)

    await saveAndRedirect({
      scope: 'platform',
      matchedRole: result.matched_role,
      user,
      member: {
        id: result.member_id,
        email: result.member_email.trim().toLowerCase(),
        role: result.matched_role,
        actorType: 'membership',
        name: null,
        tenantId: result.member_tenant_id ?? null,
        customerGroupId: null,
        isActive: Boolean(result.member_is_active),
        createdAt: result.member_created_at ?? null,
        updatedAt: result.member_updated_at ?? null,
      },
      tenant: null,
      customerGroup: null,
      activeModuleKeys: [],
    })

    return true
  }

  const processAppLogin = async (userEmail: string, user: AuthUserSnapshot) => {
    const { data, error } = await supabase.rpc('check_login_membership', {
      p_email: userEmail,
      p_scope: 'app',
    })

    if (error) {
      console.error('[auth:app] Login access check failed', error)
      await sendBackToLogin('Login access check failed', error)
      return false
    }

    const result = Array.isArray(data) ? data[0] : data

    if (
      !result?.has_match ||
      result.member_id === null ||
      !result.member_email ||
      result.member_tenant_id === null ||
      !result.matched_role
    ) {
      await sendBackToLogin('No matching membership found for this route', result)
      return false
    }

    const { data: bootstrapData, error: bootstrapError } = await supabase.rpc(
      'get_app_bootstrap_context',
      {
        p_email: userEmail,
        p_tenant_id: result.member_tenant_id,
        p_membership_id: result.member_id,
      },
    )

    if (bootstrapError) {
      console.error('[auth:app] Bootstrap fetch failed', bootstrapError)
      await sendBackToLogin('App bootstrap fetch failed', bootstrapError)
      return false
    }

    const bootstrap = Array.isArray(bootstrapData) ? bootstrapData[0] : bootstrapData

    if (
      !bootstrap ||
      bootstrap.member_id === null ||
      bootstrap.tenant_id === null ||
      !bootstrap.tenant_name ||
      !bootstrap.tenant_slug ||
      !bootstrap.member_role
    ) {
      await sendBackToLogin('App bootstrap returned no usable context', bootstrap)
      return false
    }

    logAuthContext('App membership and bootstrap resolved', {
      login: result,
      bootstrap,
    })

    const tenant: AuthTenantSnapshot = {
      id: bootstrap.tenant_id,
      name: bootstrap.tenant_name,
      slug: bootstrap.tenant_slug,
      isActive: Boolean(bootstrap.tenant_is_active),
    }

    await saveAndRedirect({
      scope: 'app',
      matchedRole: bootstrap.member_role,
      user,
      member: {
        id: bootstrap.member_id,
        email: bootstrap.member_email?.trim().toLowerCase() ?? userEmail,
        role: bootstrap.member_role,
        actorType: 'membership',
        name: null,
        tenantId: bootstrap.tenant_id,
        customerGroupId: null,
        isActive: Boolean(bootstrap.member_is_active),
        createdAt: result.member_created_at ?? null,
        updatedAt: result.member_updated_at ?? null,
      },
      tenant,
      customerGroup: null,
      activeModuleKeys: normalizeModuleKeys(bootstrap.active_module_keys),
    })

    return true
  }

  const processShopLogin = async (
    userEmail: string,
    user: AuthUserSnapshot,
  ) => {
    const { data, error } = await supabase.rpc('check_shop_login_access', {
      p_email: userEmail,
    })

    if (error) {
      console.error('[auth:shop] Login access check failed', error)
      await sendBackToLogin('Shop login access check failed', error)
      return false
    }

    const result = Array.isArray(data) ? data[0] : data
    const matchedRole = mapShopRoleToAccessRole(result?.matched_role ?? '')

    if (
      !result?.has_match ||
      result.member_id === null ||
      result.member_tenant_id === null ||
      result.customer_group_id === null ||
      !result.member_email ||
      !matchedRole
    ) {
      await sendBackToLogin('No matching customer access found for this route', result)
      return false
    }

    const { data: bootstrapData, error: bootstrapError } = await supabase.rpc(
      'get_shop_bootstrap_context',
      {
        p_email: userEmail,
        p_tenant_id: result.member_tenant_id,
        p_customer_group_member_id: result.member_id,
      },
    )

    if (bootstrapError) {
      console.error('[auth:shop] Bootstrap fetch failed', bootstrapError)
      await sendBackToLogin('Shop bootstrap fetch failed', bootstrapError)
      return false
    }

    const bootstrap = Array.isArray(bootstrapData) ? bootstrapData[0] : bootstrapData
    const bootstrapRole = mapShopRoleToAccessRole(bootstrap?.member_role ?? '')

    if (
      !bootstrap ||
      bootstrap.member_id === null ||
      bootstrap.customer_group_id === null ||
      bootstrap.tenant_id === null ||
      !bootstrap.customer_group_name ||
      !bootstrap.tenant_name ||
      !bootstrap.tenant_slug ||
      !bootstrapRole
    ) {
      await sendBackToLogin('Shop bootstrap returned no usable context', bootstrap)
      return false
    }

    logAuthContext('Shop customer access and bootstrap resolved', {
      login: result,
      bootstrap,
    })

    const tenant: AuthTenantSnapshot = {
      id: bootstrap.tenant_id,
      name: bootstrap.tenant_name,
      slug: bootstrap.tenant_slug,
      isActive: Boolean(bootstrap.tenant_is_active),
    }

    const customerGroup: AuthCustomerGroupSnapshot = {
      id: bootstrap.customer_group_id,
      name: bootstrap.customer_group_name,
      isActive: Boolean(bootstrap.customer_group_is_active),
    }

    await saveAndRedirect({
      scope: 'shop',
      matchedRole: bootstrapRole,
      user,
      member: {
        id: bootstrap.member_id,
        email: bootstrap.member_email?.trim().toLowerCase() ?? userEmail,
        role: bootstrapRole,
        actorType: 'customer_group_member',
        name: bootstrap.member_name ?? null,
        tenantId: bootstrap.tenant_id,
        customerGroupId: bootstrap.customer_group_id,
        isActive: Boolean(bootstrap.member_is_active),
        createdAt: result.member_created_at ?? null,
        updatedAt: result.member_updated_at ?? null,
      },
      tenant,
      customerGroup,
      activeModuleKeys: normalizeModuleKeys(bootstrap.active_module_keys),
    })

    return true
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

    const user = buildUserSnapshot(session, userEmail)

    if (resolvedScope === 'platform') {
      return processPlatformLogin(userEmail, user)
    }

    if (resolvedScope === 'app') {
      return processAppLogin(userEmail, user)
    }

    return processShopLogin(userEmail, user)
  }

  const handleGoogleLogin = async () => {
    isLoading.value = true
    const callbackBaseUrl = getOAuthCallbackBaseUrl()

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${callbackBaseUrl}/auth/callback?scope=${resolvedScope}`,
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
  }
}
