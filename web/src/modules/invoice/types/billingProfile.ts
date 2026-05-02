import type { InvoiceServiceResult, SortOrder, FilterOperator, InvoiceListPage } from './index'

export type BillingProfile = {
  id: number
  tenant_id: number
  name: string
  email: string | null
  customer_group_id: number | null
  phone: string | null
  address: string | null
  created_at: string
  updated_at: string
}

export type BillingProfileListQuery = {
  tenant_id?: number
  filters?: Record<string, unknown>
  operators?: Record<string, FilterOperator>
  page?: number
  page_size?: number
  pageSize?: number
  sortBy?: string
  sortOrder?: SortOrder
}

export type CreateBillingProfileInput = Omit<
  BillingProfile,
  'id' | 'created_at' | 'updated_at'
>

export type UpdateBillingProfileInput = {
  id: number
  patch: Partial<
    Omit<BillingProfile, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>
  >
}

export type DeleteBillingProfileInput = { id: number }

export type BillingProfileServiceResult<T> = InvoiceServiceResult<T>
export type BillingProfileListPage = InvoiceListPage<BillingProfile>

export type BillingProfileStoreState = {
  items: BillingProfile[]
  total: number
  page: number
  page_size: number
  total_pages: number
  loading: boolean
  saving: boolean
  error: string | null
}
