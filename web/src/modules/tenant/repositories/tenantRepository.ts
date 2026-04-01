import { supabase } from 'src/boot/supabase'

import type { Tenant, TenantCreateInput, TenantDeleteInput, TenantUpdateInput } from '../types'

export type TenantModule = {
  id: number
  tenant_id: number
  module_key: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export type TenantModuleCreateInput = {
  tenant_id: number
  module_key: string
  is_active: boolean
}

export type TenantModuleUpdateInput = {
  id: number
  tenant_id?: number
  module_key?: string
  is_active?: boolean
}

export type TenantModuleDeleteInput = {
  id: number
}

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

/* -------------------- tenant_modules -------------------- */

const listTenantModules = async (tenantId?: number): Promise<TenantModule[]> => {
  let query = supabase
    .from('tenant_modules')
    .select('*')
    .order('id', { ascending: true })

  if (tenantId) {
    query = query.eq('tenant_id', tenantId)
  }

  const { data, error } = await query

  if (error) {
    throw error
  }

  return (data as TenantModule[] | null) ?? []
}

const createTenantModule = async (
  payload: TenantModuleCreateInput
): Promise<TenantModule> => {
  const { data, error } = await supabase
    .from('tenant_modules')
    .insert([
      {
        tenant_id: payload.tenant_id,
        module_key: payload.module_key,
        is_active: payload.is_active,
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Tenant module was not created.')
  }

  return data as TenantModule
}

const updateTenantModule = async (
  payload: TenantModuleUpdateInput
): Promise<TenantModule> => {
  const updateData: Partial<TenantModule> = {}

  if (payload.tenant_id !== undefined) {
    updateData.tenant_id = payload.tenant_id
  }

  if (payload.module_key !== undefined) {
    updateData.module_key = payload.module_key
  }

  if (payload.is_active !== undefined) {
    updateData.is_active = payload.is_active
  }

  const { data, error } = await supabase
    .from('tenant_modules')
    .update(updateData)
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Tenant module was not updated.')
  }

  return data as TenantModule
}

const deleteTenantModule = async (
  payload: TenantModuleDeleteInput
): Promise<void> => {
  const { error } = await supabase
    .from('tenant_modules')
    .delete()
    .eq('id', payload.id)

  if (error) {
    throw error
  }
}

export const tenantRepository = {
  deleteTenant,
  listTenants,
  createTenant,
  updateTenant,

  listTenantModules,
  createTenantModule,
  updateTenantModule,
  deleteTenantModule,
}
