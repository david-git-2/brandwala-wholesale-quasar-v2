import { supabase } from 'src/boot/supabase'

import type { Tenant, TenantCreateInput, TenantDeleteInput, TenantUpdateInput } from '../types'

const listTenants = async (): Promise<Tenant[]> => {
  const { data, error } = await supabase.rpc('list_tenants_for_superadmin')

  if (error) {
    throw error
  }

  return (data as Tenant[] | null) ?? []
}
const createTenant = async (tenant: TenantCreateInput): Promise<Tenant> => {
  const { data, error } = await supabase.rpc('create_tenant_for_superadmin', {
    p_name: tenant.name,
    p_slug: tenant.slug,
    p_is_active: tenant.is_active,
  })

  if (error) {
    throw error
  }

  const createdTenant = Array.isArray(data) ? data[0] : data

  if (!createdTenant) {
    throw new Error('Tenant was not created.')
  }

  return createdTenant as Tenant
}
const updateTenant = async (tenant: TenantUpdateInput): Promise<Tenant> => {
  const { data, error } = await supabase.rpc('update_tenant_for_superadmin', {
    p_tenant_id: tenant.id,
    p_name: tenant.name,
    p_slug: tenant.slug,
    p_is_active: tenant.is_active,
  })

  if (error) {
    throw error
  }

  const updatedTenant = Array.isArray(data) ? data[0] : data

  if (!updatedTenant) {
    throw new Error('Tenant was not updated.')
  }

  return updatedTenant as Tenant
}
const deleteTenant = async (tenant: TenantDeleteInput): Promise<Tenant> => {
  const { data, error } = await supabase.rpc('delete_tenant_for_superadmin', {
    p_tenant_id: tenant.id,
  })

  if (error) {
    throw error
  }

  const deletedTenant = Array.isArray(data) ? data[0] : data

  if (!deletedTenant) {
    throw new Error('Tenant was not deleted.')
  }

  return deletedTenant as Tenant
}

export const tenantRepository = {
  deleteTenant,
  listTenants,
  createTenant,
  updateTenant,
}
