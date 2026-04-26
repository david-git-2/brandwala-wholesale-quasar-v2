import { defineBoot } from '#q-app/wrappers'
import { createClient } from '@supabase/supabase-js'
import { beginGlobalRequest, endGlobalRequest } from 'src/composables/useGlobalNetworkActivity'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const defaultFetch: typeof fetch = globalThis.fetch.bind(globalThis)

const trackedFetch: typeof fetch = async (input, init) => {
  beginGlobalRequest()
  try {
    return await defaultFetch(input, init)
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

export default defineBoot(({ app }) => {
  app.config.globalProperties.$supabase = supabase
})
