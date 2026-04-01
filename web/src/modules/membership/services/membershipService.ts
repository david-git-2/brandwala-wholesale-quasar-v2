import { membershipRepository } from '../repositories/membershipRepository'
import type {
  Membership,
  MembershipCreateInput,
  MembershipDeleteInput,
  MembershipServiceResult,
  MembershipUpdateInput,
} from '../types'

const listMemberships = async (): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.listMemberships()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load memberships.',
    }
  }
}
const fetchMembershipsByTenantId = async (tenantId: number): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.fetchMembershipsByTenantId(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load memberships for tenant.',
    }
  }
}

const createMembership = async (
  membership: MembershipCreateInput
): Promise<MembershipServiceResult<Membership>> => {
  try {
    const data = await membershipRepository.createMembership(membership)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create membership.',
    }
  }
}

const updateMembership = async (
  membership: MembershipUpdateInput
): Promise<MembershipServiceResult<Membership>> => {
  try {
    const data = await membershipRepository.updateMembership(membership)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update membership.',
    }
  }
}

const deleteMembership = async (
  membership: MembershipDeleteInput
): Promise<MembershipServiceResult<null>> => {
  try {
    await membershipRepository.deleteMembership(membership)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete membership.',
    }
  }
}
const getTenantAdmins = async (tenantId: number): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.getTenantAdmins(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenant admins.',
    }
  }
}
export const membershipService = {
  deleteMembership,
  listMemberships,
  createMembership,
  updateMembership,
  getTenantAdmins,
  fetchMembershipsByTenantId,
}

