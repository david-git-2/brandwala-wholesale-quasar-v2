export type Vendor = {
  id: number
  name: string
  code: string
  market_code: string
  tenant_id: number | null
  email: string | null
  phone: string | null
  address: string | null
  website: string | null
  created_at?: string
  updated_at?: string
}

export type VendorMarket = {
  code: string
  name: string
  region: string
}

export type VendorCreateInput = {
  name: string
  code: string
  market_code: string
  tenant_id: number | null
  email?: string | null
  phone?: string | null
  address?: string | null
  website?: string | null
}

export type VendorUpdateInput = VendorCreateInput & {
  id: number
}

export type VendorDeleteInput = {
  id: number
}

export type VendorServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type VendorStoreState = {
  items: Vendor[]
  markets: VendorMarket[]
  loading: boolean
  saving: boolean
  error: string | null
}
