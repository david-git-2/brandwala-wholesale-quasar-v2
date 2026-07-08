import { customerGroupRepository } from '../repositories/customerGroupRepository';
import type {
  CustomerGroup,
  CustomerGroupCreateInput,
  CustomerGroupDeleteInput,
  CustomerGroupMember,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberDeleteInput,
  CustomerGroupMemberUpdateInput,
  CustomerGroupUpdateInput,
  TenantServiceResult,
} from '../types';

const getErrorMessage = (error: unknown, fallback: string): string => {
  if (!error) return fallback;
  if (typeof error === 'string') return error;
  if (error instanceof Error) return error.message;
  if (typeof error === 'object' && error !== null) {
    const errObj = error as Record<string, unknown>;
    const msg = errObj.message;
    if (typeof msg === 'string') return msg;
    if (typeof msg === 'number' || typeof msg === 'boolean') return String(msg);

    const desc = errObj.error_description;
    if (typeof desc === 'string') return desc;
    if (typeof desc === 'number' || typeof desc === 'boolean') return String(desc);

    const sub = errObj.error;
    if (sub && typeof sub === 'object' && sub !== null) {
      const subErr = sub as Record<string, unknown>;
      const subMsg = subErr.message;
      if (typeof subMsg === 'string') return subMsg;
      if (typeof subMsg === 'number' || typeof subMsg === 'boolean') return String(subMsg);
    }
  }
  return fallback;
};

const listCustomerGroupsByTenant = async (
  tenantId: number,
): Promise<TenantServiceResult<CustomerGroup[]>> => {
  try {
    const data = await customerGroupRepository.listCustomerGroupsByTenant(tenantId);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load customer groups.'),
    };
  }
};

const createCustomerGroup = async (
  payload: CustomerGroupCreateInput,
): Promise<TenantServiceResult<CustomerGroup>> => {
  try {
    const data = await customerGroupRepository.createCustomerGroup(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to create customer group.'),
    };
  }
};

const updateCustomerGroup = async (
  payload: CustomerGroupUpdateInput,
): Promise<TenantServiceResult<CustomerGroup>> => {
  try {
    const data = await customerGroupRepository.updateCustomerGroup(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to update customer group.'),
    };
  }
};

const deleteCustomerGroup = async (
  payload: CustomerGroupDeleteInput,
): Promise<TenantServiceResult<null>> => {
  try {
    await customerGroupRepository.deleteCustomerGroup(payload);

    return {
      success: true,
      data: null,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to delete customer group.'),
    };
  }
};

const listCustomerGroupMembersByGroup = async (
  customerGroupId: number,
): Promise<TenantServiceResult<CustomerGroupMember[]>> => {
  try {
    const data = await customerGroupRepository.listCustomerGroupMembersByGroup(customerGroupId);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load customer group members.'),
    };
  }
};

const createCustomerGroupMember = async (
  payload: CustomerGroupMemberCreateInput,
): Promise<TenantServiceResult<CustomerGroupMember>> => {
  try {
    const data = await customerGroupRepository.createCustomerGroupMember(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to create customer group member.'),
    };
  }
};

const updateCustomerGroupMember = async (
  payload: CustomerGroupMemberUpdateInput,
): Promise<TenantServiceResult<CustomerGroupMember>> => {
  try {
    const data = await customerGroupRepository.updateCustomerGroupMember(payload);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to update customer group member.'),
    };
  }
};

const deleteCustomerGroupMember = async (
  payload: CustomerGroupMemberDeleteInput,
): Promise<TenantServiceResult<null>> => {
  try {
    await customerGroupRepository.deleteCustomerGroupMember(payload);

    return {
      success: true,
      data: null,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to delete customer group member.'),
    };
  }
};

export const customerGroupService = {
  listCustomerGroupsByTenant,
  createCustomerGroup,
  updateCustomerGroup,
  deleteCustomerGroup,
  listCustomerGroupMembersByGroup,
  createCustomerGroupMember,
  updateCustomerGroupMember,
  deleteCustomerGroupMember,
};
