import { tenantRepository } from '../repositories/tenantRepository'
import type { Tenant, TenantServiceResult } from '../types'

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

export const tenantService = {
  listTenants,
}
