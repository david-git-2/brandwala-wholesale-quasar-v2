import { defineBoot } from '#q-app/wrappers'
import { createClient } from '@supabase/supabase-js'
import { beginGlobalRequest, endGlobalRequest } from 'src/composables/useGlobalNetworkActivity'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const defaultFetch: typeof fetch = globalThis.fetch.bind(globalThis)

const trackedFetch: typeof fetch = async (input, init) => {
  beginGlobalRequest()
  try {
    const storageKey = 'brandwala.tenant.workspace.v1'
    const storageValue = typeof window !== 'undefined' ? window.localStorage.getItem(storageKey) : null
    let selectedTenantId: string | null = null

    if (storageValue) {
      try {
        const parsed = JSON.parse(storageValue)
        if (parsed && parsed.selectedTenantId) {
          selectedTenantId = parsed.selectedTenantId.toString()
        }
      } catch {
        // Ignore parse errors
      }
    }

    let modifiedInit = init
    if (selectedTenantId) {
      modifiedInit = { ...init }
      const headers = new Headers(modifiedInit.headers)
      headers.set('x-selected-tenant-id', selectedTenantId)
      modifiedInit.headers = headers
    }

    const response = await defaultFetch(input, modifiedInit)

    const urlStr = typeof input === 'string' ? input : (input instanceof Request ? input.url : '')
    if (urlStr && urlStr.startsWith(supabaseUrl)) {
      try {
        const urlObj = new URL(urlStr)
        const path = urlObj.pathname

        const isMonitored = path.startsWith('/rest/v1/') || path.startsWith('/functions/v1/') || path.startsWith('/storage/v1/')
        const isExcluded = path.startsWith('/auth/v1/token') || path.startsWith('/auth/v1/authorize')

        if (isMonitored && !isExcluded) {
          if (response.status === 401) {
            import('src/modules/auth/utils/forceAuthLogout').then(({ handleUnauthorizedResponse }) => {
              void handleUnauthorizedResponse()
            })
          } else if (response.status === 403) {
            import('src/modules/auth/utils/handleForbiddenResponse').then(({ handleForbiddenResponse }) => {
              void handleForbiddenResponse(response)
            })
          }
        }
      } catch {
        // Fail silent if URL parsing fails
      }
    }

    return response
  } finally {
    endGlobalRequest()
  }
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: {
    fetch: trackedFetch,
  },
  auth: {
    detectSessionInUrl: true,
    flowType: 'pkce',
  },
})

export default defineBoot(async ({ app }) => {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    const { useAuthStore } = await import('src/modules/auth/stores/authStore')
    const authStore = useAuthStore()

    if (authStore.hasAccess && !session) {
      const { handleUnauthorizedResponse } = await import('src/modules/auth/utils/forceAuthLogout')
      await handleUnauthorizedResponse()
      return
    }
  } catch (error) {
    console.error('[supabase boot] session check error:', error)
  }

  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT' || (event === 'TOKEN_REFRESHED' && !session)) {
      import('src/modules/auth/stores/authStore').then(({ useAuthStore }) => {
        const authStore = useAuthStore()
        if (authStore.isAuthenticated) {
          import('src/modules/auth/utils/forceAuthLogout').then(({ handleUnauthorizedResponse }) => {
            void handleUnauthorizedResponse()
          })
        }
      })
    }
  })

  app.config.globalProperties.$supabase = supabase
})
