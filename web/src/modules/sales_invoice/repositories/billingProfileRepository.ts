import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/supabase';

export type BillingProfile = Database['public']['Tables']['billing_profiles']['Row'];
export type CreateBillingProfileInput = Database['public']['Tables']['billing_profiles']['Insert'];
export type UpdateBillingProfileInput = {
  id: number;
  patch: Database['public']['Tables']['billing_profiles']['Update'];
};
export type DeleteBillingProfileInput = {
  id: number;
};

export interface BillingProfileListQuery {
  tenant_id?: number;
  page?: number;
  page_size?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  filters?: Record<string, unknown>;
  operators?: Record<string, string>;
}

export interface BillingProfileListPage {
  data: BillingProfile[];
  meta: {
    total: number;
    page: number;
    page_size: number;
    total_pages: number;
  };
}

const listBillingProfiles = async (
  payload: BillingProfileListQuery = {},
): Promise<BillingProfileListPage> => {
  const pageSize = payload.page_size ?? payload.pageSize ?? 20;
  const page = payload.page ?? 1;
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  let query = supabase.from('billing_profiles').select('*', { count: 'exact' });

  if (typeof payload.tenant_id === 'number') {
    query = query.eq('tenant_id', payload.tenant_id);
  }

  const sortBy = payload.sortBy || 'created_at';
  query = query.order(sortBy, { ascending: payload.sortOrder === 'asc' }).range(from, to);

  const { data, error, count } = await query;
  if (error) throw error;

  const total = count ?? 0;
  return {
    data: (data as BillingProfile[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  };
};

const createBillingProfile = async (
  payload: CreateBillingProfileInput,
): Promise<BillingProfile> => {
  let customerGroupId = payload.customer_group_id;

  // Always ensure a customer group exists for the billing profile
  if (!customerGroupId && payload.tenant_id) {
    const { data: group, error: groupError } = await supabase
      .from('customer_groups')
      .insert([
        {
          tenant_id: payload.tenant_id,
          name: payload.name.trim(),
          is_active: true,
          accent_color: payload.color?.trim() || null,
        },
      ])
      .select()
      .single();

    if (groupError) throw groupError;
    customerGroupId = group.id;
  }

  // Check if DB trigger trg_customer_groups_auto_billing_profile created the billing profile
  if (customerGroupId) {
    const { data: existingBp } = await supabase
      .from('billing_profiles')
      .select('*')
      .eq('customer_group_id', customerGroupId)
      .maybeSingle();

    if (existingBp) {
      // Update auto-created billing profile with extra payload fields
      const patch: Partial<CreateBillingProfileInput> = {};
      if (payload.name) patch.name = payload.name.trim();
      if (payload.email !== undefined) patch.email = payload.email;
      if (payload.phone !== undefined) patch.phone = payload.phone;
      if (payload.address !== undefined) patch.address = payload.address;
      if (payload.color !== undefined) patch.color = payload.color;

      if (Object.keys(patch).length > 0) {
        const { data: updatedBp, error: updateError } = await supabase
          .from('billing_profiles')
          .update(patch)
          .eq('id', existingBp.id)
          .select('*')
          .single();

        if (updateError) throw updateError;
        return updatedBp as BillingProfile;
      }
      return existingBp as BillingProfile;
    }
  }

  // Fallback direct insert with customer_group_id attached
  const insertPayload = {
    ...payload,
    customer_group_id: customerGroupId ?? payload.customer_group_id ?? null,
  };

  const { data, error } = await supabase
    .from('billing_profiles')
    .insert([insertPayload])
    .select('*')
    .single();

  if (error) throw error;
  return data as BillingProfile;
};

const updateBillingProfile = async (
  payload: UpdateBillingProfileInput,
): Promise<BillingProfile> => {
  const { data, error } = await supabase
    .from('billing_profiles')
    .update(payload.patch)
    .eq('id', payload.id)
    .select('*')
    .single();

  if (error) throw error;
  return data as BillingProfile;
};

const deleteBillingProfile = async (payload: DeleteBillingProfileInput): Promise<void> => {
  const { error } = await supabase.from('billing_profiles').delete().eq('id', payload.id);
  if (error) throw error;
};

export const billingProfileRepository = {
  listBillingProfiles,
  createBillingProfile,
  updateBillingProfile,
  deleteBillingProfile,
};
