import { supabase } from 'src/boot/supabase'
import type { Database } from 'src/types/supabase'

export type BillingProfile = Database['public']['Tables']['billing_profiles']['Row']
export type CreateBillingProfileInput = Database['public']['Tables']['billing_profiles']['Insert']
export type UpdateBillingProfileInput = {
  id: number
  patch: Database['public']['Tables']['billing_profiles']['Update']
}
export type DeleteBillingProfileInput = {
  id: number
}

export interface BillingProfileListQuery {
  tenant_id?: number
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: 'asc' | 'desc'
  filters?: Record<string, unknown>
  operators?: Record<string, string>
}

export interface BillingProfileListPage {
  data: BillingProfile[]
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

const listBillingProfiles = async (
  payload: BillingProfileListQuery = {},
): Promise<BillingProfileListPage> => {
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
    data: (data as BillingProfile[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createBillingProfile = async (payload: CreateBillingProfileInput): Promise<BillingProfile> => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .insert([payload])
    .select('*')
    .single()

  if (error) throw error
  return data as BillingProfile
}

const updateBillingProfile = async (payload: UpdateBillingProfileInput): Promise<BillingProfile> => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) throw error
  return data as BillingProfile
}

const deleteBillingProfile = async (payload: DeleteBillingProfileInput): Promise<void> => {
  const { error } = await supabase.from('billing_profiles').delete().eq('id', payload.id)
  if (error) throw error
}

export const billingProfileRepository = {
  listBillingProfiles,
  createBillingProfile,
  updateBillingProfile,
  deleteBillingProfile,
}
