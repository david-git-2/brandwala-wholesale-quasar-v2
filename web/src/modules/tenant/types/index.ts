import type { Tables } from 'src/types/supabase'

export type Tenant = Tables<'tenants'>

export interface TenantServiceResult<T = void> {
  success: boolean
  data?: T
  error?: string
}

export interface TenantStoreState {
  items: Tenant[]
  loading: boolean
  error: string | null
}
