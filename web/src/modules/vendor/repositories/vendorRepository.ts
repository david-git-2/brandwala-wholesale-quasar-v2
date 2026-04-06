import { supabase } from 'src/boot/supabase'

import type {
  Vendor,
  VendorCreateInput,
  VendorDeleteInput,
  VendorMarket,
  VendorUpdateInput,
} from '../types'

const listVendors = async (): Promise<Vendor[]> => {
  const { data, error } = await supabase
    .from('vendors')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as Vendor[] | null) ?? []
}

const listVendorMarkets = async (): Promise<VendorMarket[]> => {
  const { data, error } = await supabase.rpc('list_vendor_markets')

  if (error) {
    throw error
  }

  return (data as VendorMarket[] | null) ?? []
}

const isVendorCodeAvailable = async (
  code: string,
  excludeId?: number | null,
): Promise<boolean> => {
  const { data, error } = await supabase.rpc('is_vendor_code_available', {
    p_code: code,
    p_exclude_id: excludeId ?? null,
  })

  if (error) {
    throw error
  }

  return Boolean(data)
}

const createVendor = async (payload: VendorCreateInput): Promise<Vendor> => {
  const { data, error } = await supabase
    .from('vendors')
    .insert([
      {
        name: payload.name.trim(),
        code: payload.code.trim().toUpperCase(),
        market_code: payload.market_code.trim().toUpperCase(),
        tenant_id: payload.tenant_id,
        email: payload.email?.trim() || null,
        phone: payload.phone?.trim() || null,
        address: payload.address?.trim() || null,
        website: payload.website?.trim() || null,
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Vendor was not created.')
  }

  return data as Vendor
}

const updateVendor = async (payload: VendorUpdateInput): Promise<Vendor> => {
  const { data, error } = await supabase
    .from('vendors')
    .update({
      name: payload.name.trim(),
      code: payload.code.trim().toUpperCase(),
      market_code: payload.market_code.trim().toUpperCase(),
      tenant_id: payload.tenant_id,
      email: payload.email?.trim() || null,
      phone: payload.phone?.trim() || null,
      address: payload.address?.trim() || null,
      website: payload.website?.trim() || null,
    })
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Vendor was not updated.')
  }

  return data as Vendor
}

const deleteVendor = async (payload: VendorDeleteInput): Promise<void> => {
  const { error } = await supabase
    .from('vendors')
    .delete()
    .eq('id', payload.id)

  if (error) {
    throw error
  }
}

export const vendorRepository = {
  listVendors,
  listVendorMarkets,
  isVendorCodeAvailable,
  createVendor,
  updateVendor,
  deleteVendor,
}
