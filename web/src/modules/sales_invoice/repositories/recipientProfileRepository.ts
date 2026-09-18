import { supabase } from 'src/boot/supabase';
import type {
  RecipientProfile,
  CreateRecipientProfileInput,
  UpdateRecipientProfileInput,
} from 'src/types/recipientProfile';

const mapProfileJson = (data: Record<string, unknown> | null): RecipientProfile | null => {
  if (!data || data.id == null) return null;
  return {
    id: Number(data.id),
    tenant_id: data.tenant_id != null ? Number(data.tenant_id) : null,
    parent_tenant_id: data.parent_tenant_id != null ? Number(data.parent_tenant_id) : null,
    name: (data.name as string | null) ?? '',
    phone: (data.phone as string | null) ?? '',
    secondary_phone: (data.secondary_phone as string | null) ?? null,
    address: (data.address as string | null) ?? '',
    district: (data.district as string | null) ?? null,
    thana: (data.thana as string | null) ?? null,
    addresses: (data.addresses as RecipientProfile['addresses']) ?? [],
    created_at: (data.created_at as string | null) ?? '',
    updated_at: (data.updated_at as string | null) ?? '',
    tenant_name:
      (data.tenants as { name?: string | null } | null)?.name ??
      (data.tenant_name as string | null) ??
      null,
  };
};

export const recipientProfileRepository = {
  async list(tenantId: number, isParent?: boolean): Promise<RecipientProfile[]> {
    let query = supabase
      .from('recipient_profiles')
      .select('*, tenants:tenant_id(name)');
    if (isParent) {
      query = query.eq('parent_tenant_id', tenantId);
    } else {
      query = query.eq('tenant_id', tenantId);
    }
    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []).map((row: any) => ({
      ...row,
      tenant_name: row.tenants?.name ?? null,
    }));
  },

  async getByPhone(tenantId: number, phone: string): Promise<RecipientProfile | null> {
    const { data, error } = await supabase.rpc('get_recipient_profile_by_phone', {
      p_tenant_id: tenantId,
      p_phone: phone,
    });
    if (error) throw error;
    return mapProfileJson(data as Record<string, unknown> | null);
  },

  async upsertByPhone(payload: {
    tenant_id?: number | null;
    parent_tenant_id?: number | null;
    name: string;
    phone: string;
    secondary_phone?: string | null;
    address: string;
    district?: string | null;
    thana?: string | null;
  }): Promise<RecipientProfile> {
    const targetTenantId = payload.parent_tenant_id ?? payload.tenant_id;
    if (!targetTenantId) throw new Error('Tenant ID or Parent Tenant ID is required');
    const { data, error } = await supabase.rpc('upsert_recipient_profile_by_phone', {
      p_tenant_id: targetTenantId,
      p_name: payload.name,
      p_phone: payload.phone,
      p_secondary_phone: payload.secondary_phone ?? null,
      p_address: payload.address,
      p_district: payload.district ?? null,
      p_thana: payload.thana ?? null,
    });
    if (error) throw error;
    const mapped = mapProfileJson(data as Record<string, unknown> | null);
    if (!mapped) throw new Error('Upsert returned empty recipient profile');
    return mapped;
  },

  async create(payload: CreateRecipientProfileInput): Promise<RecipientProfile> {
    const { data, error } = await supabase
      .from('recipient_profiles')
      .insert([payload])
      .select('*')
      .single();
    if (error) throw error;
    return data;
  },

  async update(payload: UpdateRecipientProfileInput): Promise<RecipientProfile> {
    const { data, error } = await supabase
      .from('recipient_profiles')
      .update(payload.patch)
      .eq('id', payload.id)
      .select('*')
      .single();
    if (error) throw error;
    return data;
  },

  async delete(id: number): Promise<void> {
    const { error } = await supabase.from('recipient_profiles').delete().eq('id', id);
    if (error) throw error;
  },
};
