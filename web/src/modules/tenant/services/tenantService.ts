import { tenantRepository } from '../repositories/tenantRepository';
import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantEntry,
  TenantEntryResolveInput,
  TenantPreferenceUpdateInput,
  TenantServiceResult,
  TenantUpdateInput,
  TenantModule,
  TenantModuleCreateInput,
  TenantModuleDeleteInput,
  TenantModuleUpdateInput,
  TenantModuleSubmoduleSetInput,
} from '../types';

const listTenants = async (): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listTenants();

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenants.',
    };
  }
};

const resolveTenantForEntry = async (
  payload: TenantEntryResolveInput,
): Promise<TenantServiceResult<TenantEntry | null>> => {
  try {
    const data = await tenantRepository.resolveTenantForEntry(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to resolve tenant entry context.',
    };
  }
};

const listTenantsByMembership = async (payload?: {
  tenantId?: number | null;
  email?: string | null;
  role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null;
}): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listTenantsByMembership(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenants.',
    };
  }
};

const getTenantDetailsByMembership = async (payload: {
  tenantId: number;
  email?: string | null;
  role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null;
}): Promise<TenantServiceResult<Tenant | null>> => {
  try {
    const data = await tenantRepository.getTenantDetailsByMembership(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenant details.',
    };
  }
};

const listAdminTenantsByEmail = async (): Promise<TenantServiceResult<Tenant[]>> => {
  try {
    const data = await tenantRepository.listAdminTenantsByEmail();

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenants.',
    };
  }
};

const createTenant = async (tenant: TenantCreateInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.createTenant(tenant);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create tenant.',
    };
  }
};

const updateTenant = async (tenant: TenantUpdateInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.updateTenant(tenant);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update tenant.',
    };
  }
};

const updateTenantPreference = async (
  input: TenantPreferenceUpdateInput,
): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.updateTenantPreference(input);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update tenant preference.',
    };
  }
};

const deleteTenant = async (tenant: TenantDeleteInput): Promise<TenantServiceResult<Tenant>> => {
  try {
    const data = await tenantRepository.deleteTenant(tenant);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete tenant.',
    };
  }
};

const listTenantModules = async (
  tenantId?: number,
): Promise<TenantServiceResult<TenantModule[]>> => {
  try {
    const data = await tenantRepository.listTenantModules(tenantId);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenant modules.',
    };
  }
};

const createTenantModule = async (
  payload: TenantModuleCreateInput,
): Promise<TenantServiceResult<TenantModule>> => {
  try {
    const data = await tenantRepository.createTenantModule(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create tenant module.',
    };
  }
};

const updateTenantModule = async (
  payload: TenantModuleUpdateInput,
): Promise<TenantServiceResult<TenantModule>> => {
  try {
    const data = await tenantRepository.updateTenantModule(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update tenant module.',
    };
  }
};

const deleteTenantModule = async (
  payload: TenantModuleDeleteInput,
): Promise<TenantServiceResult<null>> => {
  try {
    await tenantRepository.deleteTenantModule(payload);

    return {
      success: true,
      data: null,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete tenant module.',
    };
  }
};

const listTenantModuleSubmodules = async (tenantId: number, parentModuleKey: string) => {
  try {
    const data = await tenantRepository.listTenantModuleSubmodules(tenantId, parentModuleKey);
    return { success: true as const, data };
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load submodule overrides.',
    };
  }
};

const setTenantModuleSubmodule = async (payload: TenantModuleSubmoduleSetInput) => {
  try {
    const data = await tenantRepository.setTenantModuleSubmodule(payload);
    return { success: true as const, data };
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to update submodule access.',
    };
  }
};

export const tenantService = {
  deleteTenant,
  listTenants,
  resolveTenantForEntry,
  createTenant,
  updateTenant,
  updateTenantPreference,

  listTenantModules,
  createTenantModule,
  updateTenantModule,
  deleteTenantModule,
  listTenantModuleSubmodules,
  setTenantModuleSubmodule,
  listAdminTenantsByEmail,
  listTenantsByMembership,
  getTenantDetailsByMembership,
};
