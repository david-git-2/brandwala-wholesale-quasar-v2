import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/supabase';

export type CustomerProfile = Database['public']['Tables']['profiles']['Row'];
export type CreateCustomerProfileInput = {
  parent_tenant_id: number;
  operating_tenant_id?: number;
  name: string;
  email?: string | null;
  phone?: string | null;
  phone_country_code?: string;
  address?: string | null;
  customer_group_id?: number | null;
  accent_color?: string | null;
};
export type UpdateCustomerProfileInput = {
  id: number;
  patch: Database['public']['Tables']['profiles']['Update'];
};
export type DeleteCustomerProfileInput = {
  id: number;
};

export interface CustomerProfileListQuery {
  tenant_id?: number;
  page?: number;
  page_size?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

export interface CustomerProfileListPage {
  data: CustomerProfile[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
  };
}

const listCustomerProfiles = async (
  payload: CustomerProfileListQuery = {},
): Promise<CustomerProfileListPage> => {
  const pageSize = payload.page_size ?? payload.pageSize ?? 20;
  const page = payload.page ?? 1;
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  let query = supabase
    .from('profiles')
    .select('*', { count: 'exact' })
    .eq('profile_type', 'customer');

  if (typeof payload.tenant_id === 'number') {
    query = query.or(
      `operating_tenant_id.eq.${payload.tenant_id},parent_tenant_id.eq.${payload.tenant_id}`,
    );
  }

  const sortBy = payload.sortBy || 'created_at';
  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to);

  const { data, error, count } = await query;
  if (error) throw error;

  const total = count ?? 0;
  return {
    data: (data as CustomerProfile[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  };
};

const createCustomerProfile = async (
  payload: CreateCustomerProfileInput,
): Promise<CustomerProfile> => {
  let customerGroupId = payload.customer_group_id ?? null;
  const booksId = payload.parent_tenant_id;
  const operatingTenantId = payload.operating_tenant_id ?? booksId;

  if (!customerGroupId) {
    const { data: group, error: groupError } = await supabase
      .from('customer_groups')
      .insert([
        {
          tenant_id: booksId,
          name: payload.name.trim(),
          is_active: true,
          accent_color: payload.accent_color?.trim() || null,
        },
      ])
      .select()
      .single();

    if (groupError) throw groupError;
    customerGroupId = group.id;
  }

  if (customerGroupId) {
    const { data: existing } = await supabase
      .from('profiles')
      .select('*')
      .eq('customer_group_id', customerGroupId)
      .eq('profile_type', 'customer')
      .maybeSingle();

    if (existing) {
      const patch: Database['public']['Tables']['profiles']['Update'] = {};
      if (payload.name) patch.name = payload.name.trim();
      if (payload.email !== undefined) patch.email = payload.email;
      if (payload.phone !== undefined) patch.phone = payload.phone;
      if (payload.address !== undefined) patch.address = payload.address;
      if (payload.accent_color !== undefined) patch.accent_color = payload.accent_color;

      if (Object.keys(patch).length > 0) {
        const { data: updated, error: updateError } = await supabase
          .from('profiles')
          .update(patch)
          .eq('id', existing.id)
          .select('*')
          .single();

        if (updateError) throw updateError;
        return updated as CustomerProfile;
      }
      return existing as CustomerProfile;
    }
  }

  const { data, error } = await supabase
    .from('profiles')
    .insert([
      {
        parent_tenant_id: booksId,
        operating_tenant_id: operatingTenantId,
        profile_type: 'customer',
        subject_id: customerGroupId ?? booksId,
        customer_group_id: customerGroupId,
        name: payload.name.trim(),
        email: payload.email ?? null,
        phone: payload.phone ?? null,
        phone_country_code: payload.phone_country_code ?? '+880',
        address: payload.address ?? null,
        accent_color: payload.accent_color ?? null,
        is_active: true,
      },
    ])
    .select('*')
    .single();

  if (error) throw error;
  const row = data as CustomerProfile;
  if (row.id) {
    await supabase.from('profiles').update({ subject_id: row.id }).eq('id', row.id);
  }
  return row;
};

const updateCustomerProfile = async (
  payload: UpdateCustomerProfileInput,
): Promise<CustomerProfile> => {
  const { data, error } = await supabase
    .from('profiles')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single();

  if (error) throw error;
  return data as CustomerProfile;
};

const deleteCustomerProfile = async (payload: DeleteCustomerProfileInput): Promise<void> => {
  const { error } = await supabase.from('profiles').delete().eq('id', payload.id);
  if (error) throw error;
};

export const customerProfileRepository = {
  listCustomerProfiles,
  createCustomerProfile,
  updateCustomerProfile,
  deleteCustomerProfile,
};
