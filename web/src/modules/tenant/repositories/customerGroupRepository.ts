import { supabase } from 'src/boot/supabase';

import type {
  CustomerGroup,
  CustomerGroupCreateInput,
  CustomerGroupDeleteInput,
  CustomerGroupMember,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberDeleteInput,
  CustomerGroupMemberUpdateInput,
  CustomerGroupUpdateInput,
} from '../types';

const listCustomerGroupsByTenant = async (tenantId: number): Promise<CustomerGroup[]> => {
  const { data, error } = await supabase
    .from('customer_groups')
    .select('*')
    .eq('tenant_id', tenantId)
    .is('deleted_at', null)
    .order('id', { ascending: true });

  if (error) {
    throw error;
  }

  return (data as CustomerGroup[] | null) ?? [];
};

const createCustomerGroup = async (payload: CustomerGroupCreateInput & {
  admin_name?: string | null;
  admin_email?: string | null;
  phone?: string | null;
  address?: string | null;
}): Promise<CustomerGroup> => {
  const { data, error } = await supabase
    .from('customer_groups')
    .insert([
      {
        tenant_id: payload.tenant_id,
        name: payload.name.trim(),
        is_active: payload.is_active,
        accent_color: payload.accent_color?.trim() || null,
      },
    ])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Customer group was not created.');
  }

  const group = data as CustomerGroup;
  const adminName = payload.admin_name?.trim() || `${group.name} Admin`;

  // 1. Create admin member if admin email provided
  if (payload.admin_email?.trim()) {
    const email = payload.admin_email.trim().toLowerCase();
    await supabase.from('customer_group_members').insert([
      {
        customer_group_id: group.id,
        name: adminName,
        email,
        role: 'admin' as const,
        is_active: true,
      },
    ]);
  }

  // 2. Update auto-created billing profile with initial phone, address, email, name if provided
  const emailVal = payload.admin_email?.trim() || null;
  const phoneVal = payload.phone?.trim() || null;
  const addressVal = payload.address?.trim() || null;

  await supabase
    .from('profiles')
    .update({
      name: adminName,
      email: emailVal,
      phone: phoneVal,
      address: addressVal,
      accent_color: payload.accent_color?.trim() || null,
    })
    .eq('customer_group_id', group.id)
    .eq('profile_type', 'customer');

  return group;
};

const updateCustomerGroup = async (payload: CustomerGroupUpdateInput & {
  admin_name?: string | null;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
}): Promise<CustomerGroup> => {
  const updateData: Partial<CustomerGroup> = {};

  if (payload.tenant_id !== undefined) {
    updateData.tenant_id = payload.tenant_id;
  }

  if (payload.name !== undefined) {
    updateData.name = payload.name.trim();
  }

  if (payload.is_active !== undefined) {
    updateData.is_active = payload.is_active;
  }

  if (payload.accent_color !== undefined) {
    updateData.accent_color = payload.accent_color?.trim() || null;
  }

  const { data, error } = await supabase
    .from('customer_groups')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Customer group was not updated.');
  }

  const group = data as CustomerGroup;

  // Sync update to associated billing profile
  const bpUpdate: Record<string, any> = {};
  if (payload.admin_name !== undefined) bpUpdate.name = payload.admin_name?.trim() || group.name;
  if (payload.accent_color !== undefined) bpUpdate.color = payload.accent_color?.trim() || null;
  if (payload.email !== undefined) bpUpdate.email = payload.email?.trim() || null;
  if (payload.phone !== undefined) bpUpdate.phone = payload.phone?.trim() || null;
  if (payload.address !== undefined) bpUpdate.address = payload.address?.trim() || null;

  if (Object.keys(bpUpdate).length > 0) {
    await supabase
      .from('profiles')
      .update(bpUpdate)
      .eq('customer_group_id', group.id);
  }

  // Also sync admin member name if admin_name was provided
  if (payload.admin_name?.trim()) {
    await supabase
      .from('customer_group_members')
      .update({ name: payload.admin_name.trim() })
      .eq('customer_group_id', group.id)
      .eq('role', 'admin');
  }

  return group;
};

const deleteCustomerGroup = async (payload: CustomerGroupDeleteInput): Promise<void> => {
  const { error } = await supabase.rpc('delete_customer_group', { p_id: payload.id });

  if (error) {
    throw error;
  }
};

const listCustomerGroupMembersByGroup = async (
  customerGroupId: number,
): Promise<CustomerGroupMember[]> => {
  const { data, error } = await supabase
    .from('customer_group_members')
    .select('*')
    .eq('customer_group_id', customerGroupId)
    .order('id', { ascending: true });

  if (error) {
    throw error;
  }

  return (data as CustomerGroupMember[] | null) ?? [];
};

const createCustomerGroupMember = async (
  payload: CustomerGroupMemberCreateInput,
): Promise<CustomerGroupMember> => {
  const { data, error } = await supabase
    .from('customer_group_members')
    .insert([
      {
        customer_group_id: payload.customer_group_id,
        name: payload.name.trim(),
        email: payload.email.trim().toLowerCase(),
        role: payload.role,
        is_active: payload.is_active,
        tenant_role_id: payload.tenant_role_id || null,
      },
    ])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Customer group member was not created.');
  }

  return data as CustomerGroupMember;
};

const updateCustomerGroupMember = async (
  payload: CustomerGroupMemberUpdateInput,
): Promise<CustomerGroupMember> => {
  const updateData: Partial<CustomerGroupMember> = {};

  if (payload.customer_group_id !== undefined) {
    updateData.customer_group_id = payload.customer_group_id;
  }

  if (payload.name !== undefined) {
    updateData.name = payload.name.trim();
  }

  if (payload.email !== undefined) {
    updateData.email = payload.email.trim().toLowerCase();
  }

  if (payload.role !== undefined) {
    updateData.role = payload.role;
  }

  if (payload.is_active !== undefined) {
    updateData.is_active = payload.is_active;
  }

  if (payload.tenant_role_id !== undefined) {
    updateData.tenant_role_id = payload.tenant_role_id;
  }

  const { data, error } = await supabase
    .from('customer_group_members')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Customer group member was not updated.');
  }

  return data as CustomerGroupMember;
};

const deleteCustomerGroupMember = async (
  payload: CustomerGroupMemberDeleteInput,
): Promise<void> => {
  const { error } = await supabase.from('customer_group_members').delete().eq('id', payload.id);

  if (error) {
    throw error;
  }
};

const createAndLinkToCustomerProfile = async (payload: {
  profile_id: number;
  tenant_id: number;
  name: string;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
  accent_color?: string | null;
}): Promise<CustomerGroup> => {
  // 1. Create the customer group
  const { data: group, error: groupError } = await supabase
    .from('customer_groups')
    .insert([
      {
        tenant_id: payload.tenant_id,
        name: payload.name.trim(),
        is_active: true,
        accent_color: payload.accent_color?.trim() || null,
      },
    ])
    .select()
    .single();

  if (groupError || !group) {
    throw groupError || new Error('Failed to create customer group.');
  }

  const createdGroup = group as CustomerGroup;

  // 2. Link existing customer profile to newly created customer group
  const { error: bpError } = await supabase
    .from('profiles')
    .update({
      customer_group_id: createdGroup.id,
      name: payload.name.trim(),
      email: payload.email?.trim() || null,
      phone: payload.phone?.trim() || null,
      address: payload.address?.trim() || null,
      accent_color: payload.accent_color?.trim() || null,
    })
    .eq('id', payload.profile_id);

  if (bpError) {
    throw bpError;
  }

  // 3. Clean up any redundant auto-created profile from DB trigger
  await supabase
    .from('profiles')
    .delete()
    .eq('customer_group_id', createdGroup.id)
    .neq('id', payload.profile_id);

  // 4. Create admin member if email provided
  if (payload.email?.trim()) {
    const adminName = payload.name.trim() ? `${payload.name.trim()} Admin` : 'Admin';
    await supabase.from('customer_group_members').insert([
      {
        customer_group_id: createdGroup.id,
        name: adminName,
        email: payload.email.trim().toLowerCase(),
        role: 'admin' as const,
        is_active: true,
      },
    ]);
  }

  return createdGroup;
};

export const customerGroupRepository = {
  listCustomerGroupsByTenant,
  createCustomerGroup,
  createAndLinkToCustomerProfile,
  updateCustomerGroup,
  deleteCustomerGroup,
  listCustomerGroupMembersByGroup,
  createCustomerGroupMember,
  updateCustomerGroupMember,
  deleteCustomerGroupMember,
};

