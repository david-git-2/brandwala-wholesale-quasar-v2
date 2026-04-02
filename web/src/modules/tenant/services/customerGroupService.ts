import { customerGroupRepository } from '../repositories/customerGroupRepository'
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
} from '../types'

const listCustomerGroupsByTenant = async (
  tenantId: number,
): Promise<TenantServiceResult<CustomerGroup[]>> => {
  try {
    const data = await customerGroupRepository.listCustomerGroupsByTenant(tenantId)

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
          : 'Failed to load customer groups.',
    }
  }
}

const createCustomerGroup = async (
  payload: CustomerGroupCreateInput,
): Promise<TenantServiceResult<CustomerGroup>> => {
  try {
    const data = await customerGroupRepository.createCustomerGroup(payload)

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
          : 'Failed to create customer group.',
    }
  }
}

const updateCustomerGroup = async (
  payload: CustomerGroupUpdateInput,
): Promise<TenantServiceResult<CustomerGroup>> => {
  try {
    const data = await customerGroupRepository.updateCustomerGroup(payload)

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
          : 'Failed to update customer group.',
    }
  }
}

const deleteCustomerGroup = async (
  payload: CustomerGroupDeleteInput,
): Promise<TenantServiceResult<null>> => {
  try {
    await customerGroupRepository.deleteCustomerGroup(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to delete customer group.',
    }
  }
}

const listCustomerGroupMembersByGroup = async (
  customerGroupId: number,
): Promise<TenantServiceResult<CustomerGroupMember[]>> => {
  try {
    const data = await customerGroupRepository.listCustomerGroupMembersByGroup(
      customerGroupId,
    )

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
          : 'Failed to load customer group members.',
    }
  }
}

const createCustomerGroupMember = async (
  payload: CustomerGroupMemberCreateInput,
): Promise<TenantServiceResult<CustomerGroupMember>> => {
  try {
    const data = await customerGroupRepository.createCustomerGroupMember(payload)

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
          : 'Failed to create customer group member.',
    }
  }
}

const updateCustomerGroupMember = async (
  payload: CustomerGroupMemberUpdateInput,
): Promise<TenantServiceResult<CustomerGroupMember>> => {
  try {
    const data = await customerGroupRepository.updateCustomerGroupMember(payload)

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
          : 'Failed to update customer group member.',
    }
  }
}

const deleteCustomerGroupMember = async (
  payload: CustomerGroupMemberDeleteInput,
): Promise<TenantServiceResult<null>> => {
  try {
    await customerGroupRepository.deleteCustomerGroupMember(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to delete customer group member.',
    }
  }
}

export const customerGroupService = {
  listCustomerGroupsByTenant,
  createCustomerGroup,
  updateCustomerGroup,
  deleteCustomerGroup,
  listCustomerGroupMembersByGroup,
  createCustomerGroupMember,
  updateCustomerGroupMember,
  deleteCustomerGroupMember,
}
