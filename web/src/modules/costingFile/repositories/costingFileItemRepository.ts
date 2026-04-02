import { supabase } from 'src/boot/supabase'

import type {
  CostingFileItem,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemRequestCreateInput,
  CostingFileItemStatusUpdateInput,
} from '../types'

const listCostingFileItems = async (costingFileId: number): Promise<CostingFileItem[]> => {
  const { data, error } = await supabase.rpc('list_costing_file_items', {
    p_costing_file_id: costingFileId,
  })

  if (error) {
    throw error
  }

  return (data as CostingFileItem[] | null) ?? []
}

const createCostingFileItemRequest = async (
  payload: CostingFileItemRequestCreateInput,
): Promise<
  Pick<
    CostingFileItem,
    'id' | 'costing_file_id' | 'website_url' | 'quantity' | 'status' | 'created_by_email' | 'created_at' | 'updated_at'
  >
> => {
  const { data, error } = await supabase.rpc('create_costing_file_item_request', {
    p_costing_file_id: payload.costingFileId,
    p_website_url: payload.websiteUrl,
    p_quantity: payload.quantity,
  })

  if (error) {
    throw error
  }

  const created = Array.isArray(data) ? data[0] : data

  if (!created) {
    throw new Error('Costing item request was not created.')
  }

  return created as Pick<
    CostingFileItem,
    'id' | 'costing_file_id' | 'website_url' | 'quantity' | 'status' | 'created_by_email' | 'created_at' | 'updated_at'
  >
}

const updateCostingFileItemEnrichment = async (
  payload: CostingFileItemEnrichmentUpdateInput,
): Promise<CostingFileItem> => {
  const { data, error } = await supabase.rpc('update_costing_file_item_enrichment', {
    p_id: payload.id,
    p_name: payload.name ?? null,
    p_image_url: payload.imageUrl ?? null,
    p_product_weight: payload.productWeight ?? null,
    p_package_weight: payload.packageWeight ?? null,
    p_price_in_web_gbp: payload.priceInWebGbp ?? null,
    p_delivery_price_gbp: payload.deliveryPriceGbp ?? null,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Costing item enrichment was not updated.')
  }

  return updated as CostingFileItem
}

const updateCostingFileItemCustomerProfit = async (
  payload: CostingFileItemCustomerProfitUpdateInput,
): Promise<Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>> => {
  const { data, error } = await supabase.rpc('update_costing_file_item_customer_profit', {
    p_id: payload.id,
    p_customer_profit_rate: payload.customerProfitRate,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Customer profit rate was not updated.')
  }

  return updated as Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>
}

const updateCostingFileItemStatus = async (
  payload: CostingFileItemStatusUpdateInput,
): Promise<Pick<CostingFileItem, 'id' | 'status' | 'updated_at'>> => {
  const { data, error } = await supabase.rpc('update_costing_file_item_status', {
    p_id: payload.id,
    p_status: payload.status,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Item status was not updated.')
  }

  return updated as Pick<CostingFileItem, 'id' | 'status' | 'updated_at'>
}

const updateCostingFileItemOffer = async (
  payload: CostingFileItemOfferUpdateInput,
): Promise<
  Pick<CostingFileItem, 'id' | 'offer_price_override_bdt' | 'offer_price_bdt' | 'updated_at'>
> => {
  const { data, error } = await supabase.rpc('update_costing_file_item_offer', {
    p_id: payload.id,
    p_auxiliary_price_gbp: null,
    p_item_price_gbp: null,
    p_cargo_rate: null,
    p_costing_price_gbp: null,
    p_costing_price_bdt: null,
    p_offer_price_override_bdt: payload.offerPriceOverrideBdt ?? null,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Offer override was not updated.')
  }

  return updated as Pick<
    CostingFileItem,
    'id' | 'offer_price_override_bdt' | 'offer_price_bdt' | 'updated_at'
  >
}

export const costingFileItemRepository = {
  listCostingFileItems,
  createCostingFileItemRequest,
  updateCostingFileItemEnrichment,
  updateCostingFileItemCustomerProfit,
  updateCostingFileItemStatus,
  updateCostingFileItemOffer,
}
