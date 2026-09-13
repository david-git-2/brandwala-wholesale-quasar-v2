import type { Router } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from '../stores/authStore';
import { clearShopOrderQueryCache } from 'src/query/queryClient';
import {
  getAppRouteLocation,
  getScopeFromPath,
  getShopLoginRouteLocation,
  getTenantSlugFromPath,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

let appRouter: Router | null = null;
let isLoggingOut = false;
let sessionRefreshInFlight: Promise<boolean> | null = null;

export function setAuthSessionRouter(router: Router) {
  appRouter = router;
}

export async function tryRefreshSession(): Promise<boolean> {
  if (sessionRefreshInFlight) {
    return sessionRefreshInFlight;
  }

  sessionRefreshInFlight = (async () => {
    const {
      data: { session },
      error,
    } = await supabase.auth.refreshSession();
    return Boolean(session) && !error;
  })().finally(() => {
    sessionRefreshInFlight = null;
  });

  return sessionRefreshInFlight;
}

export async function handleUnauthorizedResponse() {
  if (isLoggingOut) return;
  isLoggingOut = true;

  try {
    const router = appRouter;
    if (!router) {
      console.warn('[auth] handleUnauthorizedResponse called before router was initialized');
      isLoggingOut = false;
      return;
    }

    const currentRoute = router.currentRoute.value;
    const routeName = (currentRoute.name as string) || '';

    const isLoginOrAuthRoute = (path: string, name?: string) => {
      if (!path) return true;
      if (path.includes('/login') || path.includes('/auth/callback')) return true;
      const loginRouteNames = [
        'admin-login-page',
        'customer-login-page',
        'superadmin-login-page',
        'investor-login-page',
        'auth-callback-page',
        'auth-callback',
      ];
      if (name && loginRouteNames.includes(name)) return true;
      return false;
    };

    if (isLoginOrAuthRoute(currentRoute.path, routeName)) {
      isLoggingOut = false;
      return;
    }

    const authStore = useAuthStore();
    let scope = authStore.scope;
    const locationPathname =
      typeof window !== 'undefined' ? window.location.pathname : currentRoute.path;
    const locationPath =
      typeof window !== 'undefined'
        ? `${window.location.pathname}${window.location.search}`
        : currentRoute.fullPath ?? currentRoute.path;
    const tenantSlug =
      authStore.tenantSlug ??
      getTenantSlugFromRoute(currentRoute) ??
      getTenantSlugFromPath(locationPathname);

    if (!scope) {
      scope =
        getScopeFromPath(locationPathname) ?? getScopeFromPath(currentRoute.path) ?? 'app';
    }

    authStore.clearAccess();
    if (scope === 'shop') {
      clearShopOrderQueryCache();
    }
    await supabase.auth.signOut();

    const loginError = 'session_expired';
    const targetRedirect =
      currentRoute.fullPath && currentRoute.fullPath !== '/'
        ? currentRoute.fullPath
        : locationPath && locationPathname !== '/'
          ? locationPath
          : undefined;

    const extraQuery: Record<string, string> = {
      login_error: loginError,
    };
    if (targetRedirect) {
      extraQuery.redirect = targetRedirect;
    }

    if (scope === 'platform') {
      await router.replace({
        name: 'superadmin-login-page',
        query: extraQuery,
      });
    } else if (scope === 'shop') {
      const loginRouteLocation = getShopLoginRouteLocation(currentRoute, extraQuery, tenantSlug);
      await router.replace(loginRouteLocation);
    } else if (scope === 'investor') {
      await router.replace({
        name: 'investor-login-page',
        params: tenantSlug ? { tenantSlug } : {},
        query: extraQuery,
      });
    } else {
      const loginRouteLocation = getAppRouteLocation(
        {
          name: 'admin-login-page',
          params: tenantSlug ? { tenantSlug } : {},
          query: {},
        },
        tenantSlug,
      );

      await router.replace({
        ...(typeof loginRouteLocation === 'string'
          ? { path: loginRouteLocation }
          : loginRouteLocation),
        query: extraQuery,
      });
    }
  } catch (err) {
    console.error('[auth] Error in forceAuthLogout:', err);
  } finally {
    isLoggingOut = false;
  }
}
