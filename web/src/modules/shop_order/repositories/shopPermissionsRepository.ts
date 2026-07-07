import { supabase } from 'src/boot/supabase'
import type {
  CustomerGroupShopProfile,
  ShopCustomerGroupAccess,
  UpsertProfilePayload,
  UpsertAccessPayload,
} from '../types'

interface CustomerGroup {
  id: number
  name: string
  is_active: boolean
}

interface Currency {
  id: number
  code: string
  name: string
}

const listCustomerGroups = async (tenantId: number): Promise<CustomerGroup[]> => {
  const { data, error } = await supabase
    .from('customer_groups')
    .select('id, name, is_active')
    .eq('tenant_id', tenantId)
    .order('name', { ascending: true })

  if (error) {
    throw error
  }

  return (data) ?? []
}

const getProfile = async (tenantId: number, customerGroupId: number): Promise<CustomerGroupShopProfile | null> => {
  const { data, error } = await supabase
    .from('customer_group_shop_profiles')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('customer_group_id', customerGroupId)
    .maybeSingle()

  if (error) {
    throw error
  }

  return data as CustomerGroupShopProfile | null
}

const upsertProfile = async (payload: UpsertProfilePayload): Promise<CustomerGroupShopProfile> => {
  const { data, error } = await supabase.rpc('upsert_customer_group_shop_profile', {
    p_tenant_id:                     payload.tenant_id,
    p_customer_group_id:              payload.customer_group_id,
    p_is_active:                      payload.is_active,
    p_default_can_browse:             payload.default_can_browse,
    p_default_see_price:              payload.default_see_price,
    p_default_can_add_to_cart:        payload.default_can_add_to_cart,
    p_default_can_place_order:        payload.default_can_place_order,
    p_default_can_negotiate:          payload.default_can_negotiate,
    p_default_can_view_quantity:      payload.default_can_view_quantity,
    p_default_can_set_dropship_price: payload.default_can_set_dropship_price,
  })

  if (error) {
    throw error
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Profile was not saved.')
  }

  return (Array.isArray(data) ? data[0] : data) as CustomerGroupShopProfile
}

const listAccessOverrides = async (shopId: number): Promise<ShopCustomerGroupAccess[]> => {
  const { data, error } = await supabase
    .from('shop_customer_group_access')
    .select('*')
    .eq('shop_id', shopId)

  if (error) {
    throw error
  }

  return (data as ShopCustomerGroupAccess[] | null) ?? []
}

const upsertAccessOverride = async (payload: UpsertAccessPayload): Promise<ShopCustomerGroupAccess> => {
  const { data, error } = await supabase.rpc('upsert_shop_customer_group_access', {
    p_shop_id:                  payload.shop_id,
    p_customer_group_id:        payload.customer_group_id,
    p_status:                   payload.status,
    p_can_browse:               payload.can_browse,
    p_see_price:                payload.see_price,
    p_can_add_to_cart:          payload.can_add_to_cart,
    p_can_place_order:          payload.can_place_order,
    p_can_negotiate:            payload.can_negotiate,
    p_can_view_quantity:        payload.can_view_quantity,
    p_can_set_dropship_price:   payload.can_set_dropship_price,
    p_price_tier_code:          payload.price_tier_code || null,
    p_credit_limit_amount:      payload.credit_limit_amount,
    p_credit_limit_currency_id: payload.credit_limit_currency_id,
  })

  if (error) {
    throw error
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Access override was not saved.')
  }

  return (Array.isArray(data) ? data[0] : data) as ShopCustomerGroupAccess
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

export const shopPermissionsRepository = {
  listCustomerGroups,
  getProfile,
  upsertProfile,
  listAccessOverrides,
  upsertAccessOverride,
  listCurrencies,
}
