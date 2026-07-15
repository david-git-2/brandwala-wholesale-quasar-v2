import { defineBoot } from '#q-app';
import { createClient } from '@supabase/supabase-js';
import { beginGlobalRequest, endGlobalRequest } from 'src/composables/useGlobalNetworkActivity';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';
const defaultFetch: typeof fetch = globalThis.fetch.bind(globalThis);
const AUTH_RETRY_HEADER = 'x-brandwala-auth-retry';

const readSelectedTenantIdFromStorage = (): string | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  const workspaceRaw = window.localStorage.getItem('brandwala.tenant.workspace.v1');
  if (workspaceRaw) {
    try {
      const parsed = JSON.parse(workspaceRaw) as { selectedTenantId?: number | string | null };
      if (parsed?.selectedTenantId != null && parsed.selectedTenantId !== '') {
        return String(parsed.selectedTenantId);
      }
    } catch {
      // Ignore parse errors
    }
  }

  // Shop login stores tenant on auth access, not always on workspace selection.
  const authRaw = window.localStorage.getItem('brandwala.auth.access.v4');
  if (authRaw) {
    try {
      const parsed = JSON.parse(authRaw) as {
        tenant?: { id?: number | null } | null;
        member?: { tenantId?: number | null } | null;
      };
      const tenantId = parsed?.tenant?.id ?? parsed?.member?.tenantId ?? null;
      if (tenantId != null) {
        return String(tenantId);
      }
    } catch {
      // Ignore parse errors
    }
  }

  return null;
};

const withSelectedTenantHeader = (init?: RequestInit): RequestInit | undefined => {
  const selectedTenantId = readSelectedTenantIdFromStorage();

  if (!selectedTenantId) {
    return init;
  }

  const nextInit = { ...init };
  const headers = new Headers(nextInit.headers);
  headers.set('x-selected-tenant-id', selectedTenantId);
  nextInit.headers = headers;
  return nextInit;
};

const isMonitoredSupabase401 = (urlStr: string): boolean => {
  if (!urlStr.startsWith(supabaseUrl)) {
    return false;
  }

  try {
    const path = new URL(urlStr).pathname;
    const isMonitored =
      path.startsWith('/rest/v1/') ||
      path.startsWith('/functions/v1/') ||
      path.startsWith('/storage/v1/');
    const isExcluded = path.startsWith('/auth/v1/token') || path.startsWith('/auth/v1/authorize');

    return isMonitored && !isExcluded;
  } catch {
    return false;
  }
};

const trackedFetch: typeof fetch = async (input, init) => {
  beginGlobalRequest();
  try {
    const modifiedInit = withSelectedTenantHeader(init);
    let response = await defaultFetch(input, modifiedInit);

    const urlStr = typeof input === 'string' ? input : input instanceof Request ? input.url : '';
    if (response.status === 401 && isMonitoredSupabase401(urlStr)) {
      const headers = new Headers(modifiedInit?.headers);
      const alreadyRetried = headers.get(AUTH_RETRY_HEADER) === '1';
      const { tryRefreshSession, handleUnauthorizedResponse } =
        await import('src/modules/auth/utils/forceAuthLogout');

      if (alreadyRetried) {
        void handleUnauthorizedResponse();
      } else {
        const refreshed = await tryRefreshSession();
        if (!refreshed) {
          void handleUnauthorizedResponse();
        } else {
          const {
            data: { session },
          } = await supabase.auth.getSession();
          if (session?.access_token) {
            const retryInit = { ...modifiedInit };
            const retryHeaders = new Headers(retryInit.headers);
            retryHeaders.set('Authorization', `Bearer ${session.access_token}`);
            retryHeaders.set(AUTH_RETRY_HEADER, '1');
            retryInit.headers = retryHeaders;
            response = await defaultFetch(input, retryInit);
          }

          if (response.status === 401) {
            void handleUnauthorizedResponse();
          }
        }
      }
    } else if (response.status === 403 && isMonitoredSupabase401(urlStr)) {
      void import('src/modules/auth/utils/handleForbiddenResponse').then(
        ({ handleForbiddenResponse }) => {
          void handleForbiddenResponse(response);
        },
      );
    }

    return response;
  } finally {
    endGlobalRequest();
  }
};

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: {
    fetch: trackedFetch,
  },
  auth: {
    detectSessionInUrl: true,
    flowType: 'pkce',
  },
});

export default defineBoot(async ({ app }) => {
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    const { useAuthStore } = await import('src/modules/auth/stores/authStore');
    const authStore = useAuthStore();

    if (authStore.hasAccess && !session) {
      const { tryRefreshSession, handleUnauthorizedResponse } =
        await import('src/modules/auth/utils/forceAuthLogout');
      const refreshed = await tryRefreshSession();
      if (!refreshed) {
        await handleUnauthorizedResponse();
      }
      return;
    }
  } catch (error) {
    console.error('[supabase boot] session check error:', error);
  }

  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT' || (event === 'TOKEN_REFRESHED' && !session)) {
      void import('src/modules/auth/stores/authStore').then(({ useAuthStore }) => {
        const authStore = useAuthStore();
        if (authStore.isAuthenticated) {
          void import('src/modules/auth/utils/forceAuthLogout').then(
            ({ handleUnauthorizedResponse }) => {
              void handleUnauthorizedResponse();
            },
          );
        }
      });
    }
  });

  app.config.globalProperties.$supabase = supabase;
});
