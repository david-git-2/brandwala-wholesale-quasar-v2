import type { Tables } from 'src/types/supabase'

export type Tenant = Tables<'tenants'>
export type TenantCreateInput = Pick<Tenant, 'name' | 'slug' | 'is_active'>
export type TenantUpdateInput = {
  id: Tenant['id']
  name: Tenant['name']
  slug: Tenant['slug']
  is_active: Tenant['is_active']
}
export type TenantDeleteInput = Pick<Tenant, 'id'>

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
