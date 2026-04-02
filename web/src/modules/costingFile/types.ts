import type { Database } from 'src/types/supabase'

export type CostingFileStatus = Database['public']['Enums']['costing_file_status']
export type CostingFileItemStatus = Database['public']['Enums']['costing_file_item_status']

export type CostingFile = {
  id: number
  name: string
  cargo_rate_1kg: number | null
  cargo_rate_2kg: number | null
  conversion_rate: number | null
  admin_profit_rate: number | null
  status: CostingFileStatus
  market: string
  customer_group_id: number
  tenant_id: number
  created_by_email: string
  created_at: string
  updated_at: string
}

export type CostingFileItem = {
  id: number
  costing_file_id: number
  name: string | null
  image_url: string | null
  website_url: string
  quantity: number
  product_weight: number | null
  package_weight: number | null
  price_in_web_gbp: number | null
  delivery_price_gbp: number | null
  auxiliary_price_gbp: number | null
  item_price_gbp: number | null
  cargo_rate: number | null
  costing_price_gbp: number | null
  costing_price_bdt: number | null
  offer_price_override_bdt: number | null
  offer_price_bdt: number | null
  customer_profit_rate: number | null
  status: CostingFileItemStatus
  created_by_email: string
  created_at: string
  updated_at: string
}

export type CostingFileListEntry = Pick<
  CostingFile,
  'id' | 'name' | 'market' | 'status' | 'customer_group_id' | 'tenant_id' | 'created_by_email' | 'created_at' | 'updated_at'
>

export type CostingFileDetails = CostingFile

export type CostingFileCreateInput = {
  tenantId: number
  customerGroupId: number
  name: string
  market: string
}

export type CostingFileItemRequestCreateInput = {
  costingFileId: number
  websiteUrl: string
  quantity: number
}

export type CostingFilePricingUpdateInput = {
  id: number
  cargoRate1Kg?: number | null
  cargoRate2Kg?: number | null
  conversionRate?: number | null
  adminProfitRate?: number | null
}

export type CostingFileStatusUpdateInput = {
  id: number
  status: CostingFileStatus
}

export type CostingFileItemEnrichmentUpdateInput = {
  id: number
  name?: string | null
  imageUrl?: string | null
  productWeight?: number | null
  packageWeight?: number | null
  priceInWebGbp?: number | null
  deliveryPriceGbp?: number | null
}

export type CostingFileItemOfferUpdateInput = {
  id: number
  offerPriceOverrideBdt?: number | null
}

export type CostingFileItemCustomerProfitUpdateInput = {
  id: number
  customerProfitRate: number | null
}

export type CostingFileItemStatusUpdateInput = {
  id: number
  status: CostingFileItemStatus
}

export type CostingFileServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}
