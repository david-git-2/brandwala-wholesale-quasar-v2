import { supabase } from 'src/boot/supabase'

import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantEntryResolveInput,
  TenantUpdateInput,
} from '../types'

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

const resolveTenantForEntry = async (
  payload: TenantEntryResolveInput,
): Promise<Tenant | null> => {
  const { data, error } = await supabase.rpc('resolve_tenant_for_entry', {
    p_slug: payload.slug ?? null,
    p_hostname: payload.hostname ?? null,
  })

  if (error) {
    throw error
  }

  const tenant = Array.isArray(data) ? data[0] : data

  return (tenant as Tenant | null) ?? null
}

const listAdminTenantsByEmail = async (): Promise<Tenant[]> => {
  const { data, error } = await supabase.rpc('list_my_admin_tenants')

  if (error) {
    throw error
  }


  return data
}

const listTenantsByMembership = async (payload?: {
  tenantId?: number | null
  email?: string | null
  role?: 'superadmin' | 'admin' | 'staff' | null
}): Promise<Tenant[]> => {
  const { data, error } = await supabase.rpc('list_tenants_by_membership', {
    p_tenant_id: payload?.tenantId ?? null,
    p_email: payload?.email ?? null,
    p_role: payload?.role ?? null,
  })

  if (error) {
    throw error
  }

  return (data as Tenant[] | null) ?? []
}

const getTenantDetailsByMembership = async (payload: {
  tenantId: number
  email?: string | null
  role?: 'superadmin' | 'admin' | 'staff' | null
}): Promise<Tenant | null> => {
  const { data, error } = await supabase.rpc('get_tenant_details_by_membership', {
    p_tenant_id: payload.tenantId,
    p_email: payload.email ?? null,
    p_role: payload.role ?? null,
  })

  if (error) {
    throw error
  }

  const tenant = Array.isArray(data) ? data[0] : data

  return (tenant as Tenant | null) ?? null
}

const createTenant = async (tenant: TenantCreateInput): Promise<Tenant> => {
  const { data, error } = await supabase.rpc('create_tenant_for_superadmin', {
    p_name: tenant.name,
    p_slug: tenant.slug,
    p_public_domain: tenant.public_domain,
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
    p_public_domain: tenant.public_domain,
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
const { data, error } = await supabase.rpc('list_tenant_modules_by_tenant', {
    p_tenant_id: tenantId,
  })


  if (error) {
    throw error
  }

  return (data as TenantModule[] | null) ?? []
}

const createTenantModule = async (
  payload: TenantModuleCreateInput
): Promise<TenantModule> => {
  const { data, error } = await supabase.rpc('create_tenant_module_for_superadmin', {
    p_tenant_id: payload.tenant_id,
    p_module_key: payload.module_key,
    p_is_active: payload.is_active,
  })

  if (error) {
    throw error
  }

  const createdTenantModule = Array.isArray(data) ? data[0] : data

  if (!createdTenantModule) {
    throw new Error('Tenant module was not created.')
  }

  return createdTenantModule as TenantModule
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

  const { data, error } = await supabase.rpc('update_tenant_module_for_superadmin', {
    p_id: payload.id,
    p_tenant_id: updateData.tenant_id ?? null,
    p_module_key: updateData.module_key ?? null,
    p_is_active: updateData.is_active ?? null,
  })

  if (error) {
    throw error
  }

  const updatedTenantModule = Array.isArray(data) ? data[0] : data

  if (!updatedTenantModule) {
    throw new Error('Tenant module was not updated.')
  }

  return updatedTenantModule as TenantModule
}

const deleteTenantModule = async (
  payload: TenantModuleDeleteInput
): Promise<void> => {
  const { error } = await supabase.rpc('delete_tenant_module_for_superadmin', {
    p_id: payload.id,
  })

  if (error) {
    throw error
  }
}

export const tenantRepository = {
  deleteTenant,
  listTenants,
  resolveTenantForEntry,
  createTenant,
  updateTenant,

  listTenantModules,
  createTenantModule,
  updateTenantModule,
  deleteTenantModule,
  listAdminTenantsByEmail,
  listTenantsByMembership,
  getTenantDetailsByMembership,
}
