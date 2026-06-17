
export interface CommerceAccounting {
  id: number
  tenant_id: number
  order_item_id: number | null
  cost_bdt: number
  shipment_item_id: number | null
  sell_price_bdt: number
  recipient_sell_price_bdt: number
  customer_group_id: number | null
  billing_profile_id: number | null
  is_customer_group_paid: boolean
  created_at: string
  updated_at: string
}

export type CommerceAccountingDetails = CommerceAccounting & {
  order_payment_status?: boolean | null
}

export interface CommerceAccountingServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}
