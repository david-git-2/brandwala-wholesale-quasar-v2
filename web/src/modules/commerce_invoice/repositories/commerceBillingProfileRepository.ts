import { supabase } from 'src/boot/supabase'
import type { Database } from 'src/types/supabase'

export type CommerceBillingProfile = Database['public']['Tables']['billing_profiles']['Row']
export type CreateCommerceBillingProfileInput = Database['public']['Tables']['billing_profiles']['Insert']
export type UpdateCommerceBillingProfileInput = {
  id: number
  patch: Database['public']['Tables']['billing_profiles']['Update']
}
export type DeleteCommerceBillingProfileInput = {
  id: number
}

export interface CommerceBillingProfileListQuery {
  tenant_id?: number
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
  filters?: Record<string, unknown>
  operators?: Record<string, string>
}

export interface CommerceBillingProfileListPage {
  data: CommerceBillingProfile[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

const listCommerceBillingProfiles = async (
  payload: CommerceBillingProfileListQuery = {},
): Promise<CommerceBillingProfileListPage> => {
  const pageSize = payload.page_size ?? payload.pageSize ?? 20
  const page = payload.page ?? 1
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('billing_profiles').select('*', { count: 'exact' })

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }

  const sortBy = payload.sortBy || 'created_at'
  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to)

  const { data, error, count } = await query
  if (error) throw error

  const total = count ?? 0
  return {
    data: (data as CommerceBillingProfile[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createCommerceBillingProfile = async (payload: CreateCommerceBillingProfileInput): Promise<CommerceBillingProfile> => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .insert([payload])
    .select('*')
    .single()

  if (error) throw error
  return data as CommerceBillingProfile
}

const updateCommerceBillingProfile = async (payload: UpdateCommerceBillingProfileInput): Promise<CommerceBillingProfile> => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) throw error
  return data as CommerceBillingProfile
}

const deleteCommerceBillingProfile = async (payload: DeleteCommerceBillingProfileInput): Promise<void> => {
  const { error } = await supabase.from('billing_profiles').delete().eq('id', payload.id)
  if (error) throw error
}

export const commerceBillingProfileRepository = {
  listCommerceBillingProfiles,
  createCommerceBillingProfile,
  updateCommerceBillingProfile,
  deleteCommerceBillingProfile,
}
