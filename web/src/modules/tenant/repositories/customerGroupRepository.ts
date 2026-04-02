import { supabase } from 'src/boot/supabase'

import type {
  CustomerGroup,
  CustomerGroupCreateInput,
  CustomerGroupDeleteInput,
  CustomerGroupMember,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberDeleteInput,
  CustomerGroupMemberUpdateInput,
  CustomerGroupUpdateInput,
} from '../types'

const listCustomerGroupsByTenant = async (
  tenantId: number,
): Promise<CustomerGroup[]> => {
  const { data, error } = await supabase
    .from('customer_groups')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as CustomerGroup[] | null) ?? []
}

const createCustomerGroup = async (
  payload: CustomerGroupCreateInput,
): Promise<CustomerGroup> => {
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
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Customer group was not created.')
  }

  return data as CustomerGroup
}

const updateCustomerGroup = async (
  payload: CustomerGroupUpdateInput,
): Promise<CustomerGroup> => {
  const updateData: Partial<CustomerGroup> = {}

  if (payload.tenant_id !== undefined) {
    updateData.tenant_id = payload.tenant_id
  }

  if (payload.name !== undefined) {
    updateData.name = payload.name.trim()
  }

  if (payload.is_active !== undefined) {
    updateData.is_active = payload.is_active
  }

  if (payload.accent_color !== undefined) {
    updateData.accent_color = payload.accent_color?.trim() || null
  }

  const { data, error } = await supabase
    .from('customer_groups')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Customer group was not updated.')
  }

  return data as CustomerGroup
}

const deleteCustomerGroup = async (
  payload: CustomerGroupDeleteInput,
): Promise<void> => {
  const { error } = await supabase
    .from('customer_groups')
    .delete()
    .eq('id', payload.id)

  if (error) {
    throw error
  }
}

const listCustomerGroupMembersByGroup = async (
  customerGroupId: number,
): Promise<CustomerGroupMember[]> => {
  const { data, error } = await supabase
    .from('customer_group_members')
    .select('*')
    .eq('customer_group_id', customerGroupId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as CustomerGroupMember[] | null) ?? []
}

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
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Customer group member was not created.')
  }

  return data as CustomerGroupMember
}

const updateCustomerGroupMember = async (
  payload: CustomerGroupMemberUpdateInput,
): Promise<CustomerGroupMember> => {
  const updateData: Partial<CustomerGroupMember> = {}

  if (payload.customer_group_id !== undefined) {
    updateData.customer_group_id = payload.customer_group_id
  }

  if (payload.name !== undefined) {
    updateData.name = payload.name.trim()
  }

  if (payload.email !== undefined) {
    updateData.email = payload.email.trim().toLowerCase()
  }

  if (payload.role !== undefined) {
    updateData.role = payload.role
  }

  if (payload.is_active !== undefined) {
    updateData.is_active = payload.is_active
  }

  const { data, error } = await supabase
    .from('customer_group_members')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Customer group member was not updated.')
  }

  return data as CustomerGroupMember
}

const deleteCustomerGroupMember = async (
  payload: CustomerGroupMemberDeleteInput,
): Promise<void> => {
  const { error } = await supabase
    .from('customer_group_members')
    .delete()
    .eq('id', payload.id)

  if (error) {
    throw error
  }
}

export const customerGroupRepository = {
  listCustomerGroupsByTenant,
  createCustomerGroup,
  updateCustomerGroup,
  deleteCustomerGroup,
  listCustomerGroupMembersByGroup,
  createCustomerGroupMember,
  updateCustomerGroupMember,
  deleteCustomerGroupMember,
}
