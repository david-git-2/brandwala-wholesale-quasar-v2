import { tenantRepository } from '../repositories/tenantRepository'
import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantServiceResult,
  TenantUpdateInput,
} from '../types'

const listTenants = async (): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listTenants()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenants.',
    }
  }
}
const createTenant = async (tenant: TenantCreateInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.createTenant(tenant)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create tenant.',
    }
  }
}
const updateTenant = async (tenant: TenantUpdateInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.updateTenant(tenant)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update tenant.',
    }
  }
}
const deleteTenant = async (tenant: TenantDeleteInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.deleteTenant(tenant)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete tenant.',
    }
  }
}

export const tenantService = {
  deleteTenant,
  listTenants,
  createTenant,
  updateTenant,

}
