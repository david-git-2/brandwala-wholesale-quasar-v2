import { supabase } from 'src/boot/supabase'

import type {
  CostingFileItemCreateInput,
  CostingFileItem,
  CostingFileItemsCustomerProfitBulkUpdateInput,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemDeleteInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemRequestCreateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileItemUpdateInput,
} from '../types'

const listCostingFileItems = async (costingFileId: number): Promise<CostingFileItem[]> => {
  const { data, error } = await supabase
    .from('costing_file_items')
    .select('*')
    .eq('costing_file_id', costingFileId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as CostingFileItem[] | null) ?? []
}

const listCostingFileItemsForCustomer = async (
  costingFileId: number,
): Promise<CostingFileItem[]> => {
  const { data, error } = await supabase
    .from('costing_file_items')
    .select(
      'id, costing_file_id, name, item_type, size, color, extra_information_1, extra_information_2, image_url, website_url, quantity, offer_price_bdt, customer_profit_rate, status, created_at, updated_at',
    )
    .eq('costing_file_id', costingFileId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return ((data as Array<
    Pick<
      CostingFileItem,
      | 'id'
      | 'costing_file_id'
      | 'name'
      | 'item_type'
      | 'size'
      | 'color'
      | 'extra_information_1'
      | 'extra_information_2'
      | 'image_url'
      | 'website_url'
      | 'quantity'
      | 'offer_price_bdt'
      | 'customer_profit_rate'
      | 'status'
      | 'created_at'
      | 'updated_at'
    >
  > | null) ?? []).map((item) => ({
    id: item.id,
    costing_file_id: item.costing_file_id,
    name: item.name,
    item_type: item.item_type,
    size: item.size,
    color: item.color,
    extra_information_1: item.extra_information_1,
    extra_information_2: item.extra_information_2,
    image_url: item.image_url,
    website_url: item.website_url,
    quantity: item.quantity,
    product_weight: null,
    package_weight: null,
    price_in_web_gbp: null,
    delivery_price_gbp: null,
    auxiliary_price_gbp: null,
    item_price_gbp: null,
    cargo_rate: null,
    costing_price_gbp: null,
    costing_price_bdt: null,
    offer_price_override_bdt: null,
    offer_price_bdt: item.offer_price_bdt,
    customer_profit_rate: item.customer_profit_rate,
    status: item.status,
    created_by_email: '',
    created_at: item.created_at,
    updated_at: item.updated_at,
  }))
}

const createCostingFileItem = async (
  payload: CostingFileItemCreateInput,
): Promise<CostingFileItem> => {
  const { data, error } = await supabase
    .from('costing_file_items')
    .insert({
      costing_file_id: payload.costingFileId,
      name: payload.name ?? null,
      item_type: payload.itemType ?? null,
      size: payload.size ?? null,
      color: payload.color ?? null,
      extra_information_1: payload.extraInformation1 ?? null,
      extra_information_2: payload.extraInformation2 ?? null,
      image_url: payload.imageUrl ?? null,
      website_url: payload.websiteUrl,
      quantity: payload.quantity,
      product_weight: payload.productWeight ?? null,
      package_weight: payload.packageWeight ?? null,
      price_in_web_gbp: payload.priceInWebGbp ?? null,
      delivery_price_gbp: payload.deliveryPriceGbp ?? null,
      auxiliary_price_gbp: payload.auxiliaryPriceGbp ?? null,
      item_price_gbp: payload.itemPriceGbp ?? null,
      cargo_rate: payload.cargoRate ?? null,
      costing_price_gbp: payload.costingPriceGbp ?? null,
      costing_price_bdt: payload.costingPriceBdt ?? null,
      offer_price_override_bdt: payload.offerPriceOverrideBdt ?? null,
      offer_price_bdt: payload.offerPriceBdt ?? null,
      customer_profit_rate: payload.customerProfitRate ?? null,
      status: payload.status ?? 'pending',
    })
    .select('*')
    .single()

  if (error) {
    throw error
  }

  return data as CostingFileItem
}

const createCostingFileItemRequest = async (
  payload: CostingFileItemRequestCreateInput,
): Promise<
  Pick<
    CostingFileItem,
    | 'id'
    | 'costing_file_id'
    | 'item_type'
    | 'website_url'
    | 'quantity'
    | 'status'
    | 'created_by_email'
    | 'created_at'
    | 'updated_at'
  >
> => {
  const { data, error } = await supabase.rpc('create_costing_file_item_request', {
    p_costing_file_id: payload.costingFileId,
    p_website_url: payload.websiteUrl,
    p_quantity: payload.quantity,
    p_item_type: payload.itemType ?? null,
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
    | 'id'
    | 'costing_file_id'
    | 'item_type'
    | 'website_url'
    | 'quantity'
    | 'status'
    | 'created_by_email'
    | 'created_at'
    | 'updated_at'
  >
}

const updateCostingFileItemEnrichment = async (
  payload: CostingFileItemEnrichmentUpdateInput,
): Promise<CostingFileItem> => {
  const { data, error } = await supabase.rpc('update_costing_file_item_enrichment', {
    p_id: payload.id,
    p_name: payload.name ?? null,
    p_item_type: payload.itemType ?? null,
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

const updateCostingFileItemsCustomerProfit = async (
  payload: CostingFileItemsCustomerProfitBulkUpdateInput,
): Promise<Array<Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>>> => {
  const { data, error } = await supabase.rpc('update_costing_file_items_customer_profit', {
    p_costing_file_id: payload.costingFileId,
    p_customer_profit_rate: payload.customerProfitRate,
  })

  if (error) {
    throw error
  }

  return ((Array.isArray(data) ? data : []) as Array<
    Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>
  >)
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

const updateCostingFileItem = async (
  payload: CostingFileItemUpdateInput,
): Promise<CostingFileItem> => {
  const updateData: Record<string, unknown> = {}

  if (payload.costingFileId !== undefined) updateData.costing_file_id = payload.costingFileId
  if (payload.name !== undefined) updateData.name = payload.name
  if (payload.itemType !== undefined) updateData.item_type = payload.itemType
  if (payload.size !== undefined) updateData.size = payload.size
  if (payload.color !== undefined) updateData.color = payload.color
  if (payload.extraInformation1 !== undefined) {
    updateData.extra_information_1 = payload.extraInformation1
  }
  if (payload.extraInformation2 !== undefined) {
    updateData.extra_information_2 = payload.extraInformation2
  }
  if (payload.imageUrl !== undefined) updateData.image_url = payload.imageUrl
  if (payload.websiteUrl !== undefined) updateData.website_url = payload.websiteUrl
  if (payload.quantity !== undefined) updateData.quantity = payload.quantity
  if (payload.productWeight !== undefined) updateData.product_weight = payload.productWeight
  if (payload.packageWeight !== undefined) updateData.package_weight = payload.packageWeight
  if (payload.priceInWebGbp !== undefined) updateData.price_in_web_gbp = payload.priceInWebGbp
  if (payload.deliveryPriceGbp !== undefined) updateData.delivery_price_gbp = payload.deliveryPriceGbp
  if (payload.auxiliaryPriceGbp !== undefined) updateData.auxiliary_price_gbp = payload.auxiliaryPriceGbp
  if (payload.itemPriceGbp !== undefined) updateData.item_price_gbp = payload.itemPriceGbp
  if (payload.cargoRate !== undefined) updateData.cargo_rate = payload.cargoRate
  if (payload.costingPriceGbp !== undefined) updateData.costing_price_gbp = payload.costingPriceGbp
  if (payload.costingPriceBdt !== undefined) updateData.costing_price_bdt = payload.costingPriceBdt
  if (payload.offerPriceOverrideBdt !== undefined) {
    updateData.offer_price_override_bdt = payload.offerPriceOverrideBdt
  }
  if (payload.offerPriceBdt !== undefined) updateData.offer_price_bdt = payload.offerPriceBdt
  if (payload.customerProfitRate !== undefined) updateData.customer_profit_rate = payload.customerProfitRate
  if (payload.status !== undefined) updateData.status = payload.status

  const { data, error } = await supabase
    .from('costing_file_items')
    .update(updateData)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  return data as CostingFileItem
}

const deleteCostingFileItem = async (
  payload: CostingFileItemDeleteInput,
): Promise<CostingFileItemDeleteInput> => {
  const { error } = await supabase.from('costing_file_items').delete().eq('id', payload.id)

  if (error) {
    throw error
  }

  return { id: payload.id }
}

export const costingFileItemRepository = {
  listCostingFileItems,
  listCostingFileItemsForCustomer,
  createCostingFileItem,
  createCostingFileItemRequest,
  updateCostingFileItemEnrichment,
  updateCostingFileItemCustomerProfit,
  updateCostingFileItemsCustomerProfit,
  updateCostingFileItemStatus,
  updateCostingFileItemOffer,
  updateCostingFileItem,
  deleteCostingFileItem,
}
