export type Membership = {
  id: number
  email: string
  tenant_id: number
  role: string
  is_active: boolean
  created_at?: string
  updated_at?: string
}

export type MembershipCreateInput = {
  tenant_id: number
  email: string
  role: string
  is_active: boolean
}

export type MembershipUpdateInput = {
  id: number
  tenant_id?: number
  email?: string
  role?: string
  is_active?: boolean
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
