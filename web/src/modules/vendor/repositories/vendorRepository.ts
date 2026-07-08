import { supabase } from 'src/boot/supabase';

import type {
  Vendor,
  VendorCreateInput,
  VendorDeleteInput,
  VendorMarket,
  VendorUpdateInput,
} from '../types';

const normalizeVendorCode = (code: string) => code.trim().toUpperCase();

const listVendors = async (tenantId?: number | null): Promise<Vendor[]> => {
  if (typeof tenantId === 'number') {
    const { data, error } = await supabase.rpc('list_vendors_for_tenant', {
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    return (data as Vendor[] | null) ?? [];
  }

  let query = supabase.from('vendors').select('*').order('id', { ascending: true });

  if (tenantId === null) {
    query = query.is('tenant_id', null);
  }

  const { data, error } = await query;

  if (error) {
    throw error;
  }

  return (data as Vendor[] | null) ?? [];
};

const getVendorById = async (id: number, tenantId?: number | null): Promise<Vendor | null> => {
  if (typeof tenantId === 'number') {
    const { data, error } = await supabase.rpc('get_vendor_for_tenant', {
      p_id: id,
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    return (data as Vendor | null) ?? null;
  }

  let query = supabase.from('vendors').select('*').eq('id', id);

  if (tenantId === null) {
    query = query.is('tenant_id', null);
  }

  const { data, error } = await query.maybeSingle();

  if (error) {
    throw error;
  }

  return data as Vendor | null;
};

const listVendorMarkets = async (): Promise<VendorMarket[]> => {
  const { data, error } = await supabase.rpc('list_vendor_markets');

  if (error) {
    throw error;
  }

  return (data as VendorMarket[] | null) ?? [];
};

const isVendorCodeAvailable = async (
  code: string,
  tenantId?: number | null,
  excludeId?: number | null,
): Promise<boolean> => {
  const candidateCode = normalizeVendorCode(code);
  let query = supabase
    .from('vendors')
    .select('id', { count: 'exact', head: true })
    .eq('code', candidateCode);

  if (typeof tenantId === 'number') {
    query = query.eq('tenant_id', tenantId);
  } else if (tenantId === null) {
    query = query.is('tenant_id', null);
  }

  if (typeof excludeId === 'number') {
    query = query.neq('id', excludeId);
  }

  const { count, error } = await query;

  if (error) {
    throw error;
  }

  return (count ?? 0) === 0;
};

const createVendor = async (payload: VendorCreateInput): Promise<Vendor> => {
  const vendorCode = normalizeVendorCode(payload.code);
  const { data, error } = await supabase
    .from('vendors')
    .insert([
      {
        name: payload.name.trim(),
        code: vendorCode,
        market_code: payload.market_code.trim().toUpperCase(),
        tenant_id: payload.tenant_id,
        email: payload.email?.trim() || null,
        phone: payload.phone?.trim() || null,
        address: payload.address?.trim() || null,
        website: payload.website?.trim() || null,
      },
    ])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Vendor was not created.');
  }

  return data as Vendor;
};

const updateVendor = async (payload: VendorUpdateInput): Promise<Vendor> => {
  const vendorCode = normalizeVendorCode(payload.code);
  let query = supabase
    .from('vendors')
    .update({
      name: payload.name.trim(),
      code: vendorCode,
      market_code: payload.market_code.trim().toUpperCase(),
      tenant_id: payload.tenant_id,
      email: payload.email?.trim() || null,
      phone: payload.phone?.trim() || null,
      address: payload.address?.trim() || null,
      website: payload.website?.trim() || null,
    })
    .eq('id', payload.id);

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id);
  } else if (payload.tenant_id === null) {
    query = query.is('tenant_id', null);
  }

  const { data, error } = await query.select().single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Vendor was not updated.');
  }

  return data as Vendor;
};

const deleteVendor = async (payload: VendorDeleteInput): Promise<void> => {
  let query = supabase.from('vendors').delete().eq('id', payload.id);

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id);
  } else if (payload.tenant_id === null) {
    query = query.is('tenant_id', null);
  }

  const { error } = await query;

  if (error) {
    throw error;
  }
};

export const vendorRepository = {
  listVendors,
  getVendorById,
  listVendorMarkets,
  isVendorCodeAvailable,
  createVendor,
  updateVendor,
  deleteVendor,
};
