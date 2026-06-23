export type GlobalCurrency = {
  id: number
  name: string
  country: string
  code: string
  symbol: string
  is_active: boolean
  is_system: boolean
  created_at?: string
  updated_at?: string
}

export type GlobalCurrencyCreateInput = {
  name: string
  country: string
  code: string
  symbol: string
  is_active: boolean
}

export type GlobalCurrencyUpdateInput = GlobalCurrencyCreateInput & {
  id: number
}

export type PaymentMethod = {
  id: number
  code: string
  name: string
  category: string
  scope: string
  sort_order: number
  is_active: boolean
  is_system: boolean
  created_at?: string
  updated_at?: string
}

export type PaymentMethodCreateInput = {
  code: string
  name: string
  category: string
  scope: string
  sort_order: number
  is_active: boolean
}

export type PaymentMethodUpdateInput = PaymentMethodCreateInput & {
  id: number
}

export type UnitOfMeasure = {
  id: number
  code: string
  name: string
  unit_type: string
  symbol: string | null
  sort_order: number
  is_active: boolean
  is_system: boolean
  created_at?: string
  updated_at?: string
}

export type UnitOfMeasureCreateInput = {
  code: string
  name: string
  unit_type: string
  symbol: string | null
  sort_order: number
  is_active: boolean
}

export type UnitOfMeasureUpdateInput = UnitOfMeasureCreateInput & {
  id: number
}

export const PAYMENT_METHOD_CATEGORIES = [
  { value: 'bd_mobile_wallet', label: 'BD Mobile Wallet' },
  { value: 'bd_bank', label: 'BD Bank' },
  { value: 'bd_cash', label: 'BD Cash' },
  { value: 'card', label: 'Card' },
  { value: 'international', label: 'International' },
] as const

export const PAYMENT_METHOD_SCOPES = [
  { value: 'bd', label: 'Bangladesh' },
  { value: 'international', label: 'International' },
  { value: 'both', label: 'Both' },
] as const

export const UNIT_TYPES = [
  { value: 'weight', label: 'Weight' },
  { value: 'count', label: 'Count' },
  { value: 'length', label: 'Length' },
  { value: 'volume', label: 'Volume' },
  { value: 'packaging', label: 'Packaging' },
] as const
