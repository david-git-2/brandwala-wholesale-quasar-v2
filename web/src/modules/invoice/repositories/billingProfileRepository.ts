import { supabase } from 'src/boot/supabase'
import type {
  BillingProfile,
  BillingProfileListPage,
  BillingProfileListQuery,
  CreateBillingProfileInput,
  DeleteBillingProfileInput,
  UpdateBillingProfileInput,
} from '../types/billingProfile'
import type { FilterOperator } from '../types'

const FIELDS = [
  'id',
  'tenant_id',
  'name',
  'email',
  'customer_group_id',
  'phone',
  'address',
  'created_at',
  'updated_at',
] as const
const FIELDS_ALLOWLIST: readonly string[] = FIELDS

const sanitizePage = (value: number | undefined, fallback: number) =>
  Number.isFinite(value) && (value ?? 0) > 0 ? Math.floor(value as number) : fallback

const applyFilters = <
  Q extends {
    eq: (c: string, v: unknown) => Q
    ilike: (c: string, v: string) => Q
    gte: (c: string, v: unknown) => Q
    lte: (c: string, v: unknown) => Q
    in: (c: string, v: unknown[]) => Q
  },
>(
  query: Q,
  filters: Record<string, unknown> | undefined,
  operators: Record<string, FilterOperator> | undefined,
): Q => {
  if (!filters) return query
  const allowed = new Set(FIELDS_ALLOWLIST)
  Object.entries(filters).forEach(([field, value]) => {
    if (!allowed.has(field) || value === undefined) return
    const op = operators?.[field] ?? 'eq'
    if (op === 'ilike' && typeof value === 'string') query = query.ilike(field, `%${value}%`)
    else if (op === 'gte') query = query.gte(field, value)
    else if (op === 'lte') query = query.lte(field, value)
    else if (op === 'in' && Array.isArray(value)) query = query.in(field, value)
    else query = query.eq(field, value)
  })
  return query
}

const listBillingProfiles = async (
  payload: BillingProfileListQuery = {},
): Promise<BillingProfileListPage> => {
  const pageSize = sanitizePage(payload.page_size ?? payload.pageSize, 20)
  const page = sanitizePage(payload.page, 1)
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase.from('billing_profiles').select('*', { count: 'exact' })

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id)
  }

  query = applyFilters(query, payload.filters, payload.operators)

  const sortBy =
    typeof payload.sortBy === 'string' && FIELDS_ALLOWLIST.includes(payload.sortBy)
      ? payload.sortBy
      : 'created_at'

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
