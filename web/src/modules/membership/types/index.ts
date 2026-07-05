export type TenantMembershipRole = 'admin' | 'staff' | 'viewer' | 'investor'

export type Membership = {
  id: number
  email: string
  tenant_id: number | null
  role: string
  is_active: boolean
  investor_id?: number | null
  created_at?: string
  updated_at?: string
}

export type MembershipCreateInput = {
  tenant_id: number | null
  email: string
  role: string
  is_active: boolean
  investor_id?: number | null
}

export type MembershipUpdateInput = {
  id: number
  tenant_id?: number | null
  email?: string
  role?: string
  is_active?: boolean
  investor_id?: number | null
}

export type MembershipDeleteInput = {
  id: number
}

export type MembershipServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type MembershipStoreState = {
  items: Membership[]
  loading: boolean
  error: string | null
}
