import { tenantRepository } from '../repositories/tenantRepository'
import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantEntry,
  TenantEntryResolveInput,
  TenantServiceResult,
  TenantUpdateInput,
  TenantModule,
  TenantModuleCreateInput,
  TenantModuleDeleteInput,
  TenantModuleUpdateInput,
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

const resolveTenantForEntry = async (
  payload: TenantEntryResolveInput,
): Promise<TenantServiceResult<TenantEntry | null>> => {
  try {
    const data = await tenantRepository.resolveTenantForEntry(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to resolve tenant entry context.',
    }
  }
}

const listTenantsByMembership = async (
  payload?: {
    tenantId?: number | null
    email?: string | null
    role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null
  }
): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listTenantsByMembership(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load tenants.',
    }
  }
}

const getTenantDetailsByMembership = async (
  payload: {
    tenantId: number
    email?: string | null
    role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null
  }
): Promise<TenantServiceResult<Tenant | null>> => {
  try {
    const data = await tenantRepository.getTenantDetailsByMembership(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load tenant details.',
    }
  }
}


const listAdminTenantsByEmail = async (): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listAdminTenantsByEmail()

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

const createTenant = async (
  tenant: TenantCreateInput
): Promise<TenantServiceResult<Tenant>> => {
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

const updateTenant = async (
  tenant: TenantUpdateInput
): Promise<TenantServiceResult<Tenant>> => {
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

const deleteTenant = async (
  tenant: TenantDeleteInput
): Promise<TenantServiceResult<Tenant>> => {
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

const listTenantModules = async (
  tenantId?: number
): Promise<TenantServiceResult<TenantModule[]>> => {
  try {
    const data = await tenantRepository.listTenantModules(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenant modules.',
    }
  }
}

const createTenantModule = async (
  payload: TenantModuleCreateInput
): Promise<TenantServiceResult<TenantModule>> => {
  try {
    const data = await tenantRepository.createTenantModule(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create tenant module.',
    }
  }
}

const updateTenantModule = async (
  payload: TenantModuleUpdateInput
): Promise<TenantServiceResult<TenantModule>> => {
  try {
    const data = await tenantRepository.updateTenantModule(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update tenant module.',
    }
  }
}

const deleteTenantModule = async (
  payload: TenantModuleDeleteInput
): Promise<TenantServiceResult<null>> => {
  try {
    await tenantRepository.deleteTenantModule(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete tenant module.',
    }
  }
}

export const tenantService = {
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
