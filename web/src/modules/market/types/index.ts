export type Market = {
  id: number
  name: string
  code: string
  is_active: boolean
  is_system: boolean
  region: string
  created_at?: string
  updated_at?: string
}

export type MarketCreateInput = {
  name: string
  code: string
  is_active: boolean
  is_system: boolean
  region: string
}

export type MarketUpdateInput = {
  id: number
  name: string
  code: string
  is_active: boolean
  is_system: boolean
  region: string
}

export type MarketDeleteInput = {
  id: number
}

export type MarketServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type MarketStoreState = {
  items: Market[]
  loading: boolean
  error: string | null
}
