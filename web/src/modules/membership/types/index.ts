export type Membership = {
  id: number
  user_id: string
  tenant_id: number
  role: string
  is_active: boolean
  created_at?: string
  updated_at?: string
}

export type MembershipCreateInput = {
  user_id: string
  tenant_id: number
  role: string
  is_active: boolean
  email?: string
}

export type MembershipUpdateInput = {
  id: number
  user_id?: string
  tenant_id?: number
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
