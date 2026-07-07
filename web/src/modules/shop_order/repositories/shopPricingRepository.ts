import { supabase } from 'src/boot/supabase'
import type {
  ShopProductListing,
  CandidateAllocation,
  UpsertListingPayload,
} from '../types'

interface Currency {
  id: number
  code: string
  name: string
}

const listListings = async (shopId: number): Promise<ShopProductListing[]> => {
  const { data, error } = await supabase.rpc('list_shop_product_listings', {
    p_shop_id: shopId,
  })

  if (error) {
    throw error
  }

  return (data as ShopProductListing[] | null) ?? []
}

const upsertListing = async (payload: UpsertListingPayload): Promise<ShopProductListing> => {
  const { data, error } = await supabase.rpc('upsert_shop_product_listing', {
    p_tenant_id:                     payload.tenant_id,
    p_shop_id:                       payload.shop_id,
    p_global_stock_allocation_id:   payload.global_stock_allocation_id,
    p_sell_price_amount:             payload.sell_price_amount,
    p_sell_price_currency_id:        payload.sell_price_currency_id,
    p_minimum_sell_price_amount:     payload.minimum_sell_price_amount ?? null,
    p_minimum_sell_price_currency_id: payload.minimum_sell_price_currency_id ?? null,
    p_show_quantity:                 payload.show_quantity ?? null,
    p_display_quantity_override:     payload.display_quantity_override ?? null,
    p_is_active:                     payload.is_active ?? true,
    p_id:                            payload.id ?? null,
  })

  if (error) {
    throw error
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Listing was not saved.')
  }

  return (Array.isArray(data) ? data[0] : data) as ShopProductListing
}

const listCandidateAllocations = async (tenantId: number, shopId: number): Promise<CandidateAllocation[]> => {
  const { data, error } = await supabase.rpc('list_allocations_for_shop_pick', {
    p_tenant_id: tenantId,
    p_shop_id: shopId,
  })

  if (error) {
    throw error
  }

  return (data as CandidateAllocation[] | null) ?? []
}

const listCurrencies = async (): Promise<Currency[]> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .select('id, code, name')
    .order('code', { ascending: true })

  if (error) {
    throw error
  }

  return (data) ?? []
}

export const shopPricingRepository = {
  listListings,
  upsertListing,
  listCandidateAllocations,
  listCurrencies,
}
