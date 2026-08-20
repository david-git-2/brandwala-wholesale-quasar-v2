import { supabase } from 'src/boot/supabase';
import type {
  CustomerAccount,
  CreateCustomerInput,
  UpdateCustomerInput,
  CustomerGroupMember,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberUpdateInput,
} from '../types/customer';

const listCustomers = async (tenantId: number, search?: string): Promise<CustomerAccount[]> => {
  const { data, error } = await supabase.rpc('list_customer_accounts', {
    p_tenant_id: tenantId,
    p_search: search?.trim() || null,
  });

  if (error) {
    throw error;
  }

  return (data as CustomerAccount[] | null) ?? [];
};

const createCustomer = async (input: CreateCustomerInput): Promise<CustomerAccount> => {
  const { data, error } = await supabase.rpc('create_customer_account', {
    p_tenant_id: input.tenant_id,
    p_group_name: input.group_name.trim(),
    p_admin_name: input.admin_name.trim(),
    p_admin_email: input.admin_email?.trim() || null,
    p_phone: input.phone?.trim() || null,
    p_address: input.address?.trim() || null,
    p_accent_color: input.accent_color?.trim() || '#B45F34',
  });

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Customer account was not created.');
  }

  return data as CustomerAccount;
};

const updateCustomer = async (input: UpdateCustomerInput): Promise<void> => {
  // 1. Update customer_groups
  const { error: groupError } = await supabase
    .from('customer_groups')
    .update({
      name: input.group_name.trim(),
      accent_color: input.accent_color?.trim() || null,
      is_active: input.is_active ?? true,
    })
    .eq('id', input.customer_group_id)
    .eq('tenant_id', input.tenant_id);

  if (groupError) throw groupError;

  // 2. Update billing_profiles
  const { error: bpError } = await supabase
    .from('billing_profiles')
    .update({
      name: input.admin_name.trim(),
      email: input.email?.trim() || null,
      phone: input.phone?.trim() || null,
      address: input.address?.trim() || null,
      color: input.accent_color?.trim() || null,
    })
    .eq('customer_group_id', input.customer_group_id)
    .eq('tenant_id', input.tenant_id);

  if (bpError) throw bpError;
};

const listCustomerMembers = async (customerGroupId: number): Promise<CustomerGroupMember[]> => {
  const { data, error } = await supabase
    .from('customer_group_members')
    .select('*')
    .eq('customer_group_id', customerGroupId)
    .order('id', { ascending: true });

  if (error) throw error;
  return (data as CustomerGroupMember[] | null) ?? [];
};

const createCustomerMember = async (
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

  if (error) throw error;
  if (!data) throw new Error('Member was not created.');
  return data as CustomerGroupMember;
};

const updateCustomerMember = async (
  payload: CustomerGroupMemberUpdateInput,
): Promise<CustomerGroupMember> => {
  const updateData: Partial<CustomerGroupMember> = {};
  if (payload.name !== undefined) updateData.name = payload.name.trim();
  if (payload.email !== undefined) updateData.email = payload.email.trim().toLowerCase();
  if (payload.role !== undefined) updateData.role = payload.role;
  if (payload.is_active !== undefined) updateData.is_active = payload.is_active;
  if (payload.tenant_role_id !== undefined) updateData.tenant_role_id = payload.tenant_role_id;

  const { data, error } = await supabase
    .from('customer_group_members')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single();

  if (error) throw error;
  if (!data) throw new Error('Member was not updated.');
  return data as CustomerGroupMember;
};

const deleteCustomerMember = async (id: number): Promise<void> => {
  const { error } = await supabase.from('customer_group_members').delete().eq('id', id);
  if (error) throw error;
};

export const customerRepository = {
  listCustomers,
  createCustomer,
  updateCustomer,
  listCustomerMembers,
  createCustomerMember,
  updateCustomerMember,
  deleteCustomerMember,
};
