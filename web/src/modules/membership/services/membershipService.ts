import { membershipRepository } from '../repositories/membershipRepository';
import type {
  Membership,
  MembershipCreateInput,
  MembershipDeleteInput,
  MembershipServiceResult,
  MembershipUpdateInput,
} from '../types';
import type { MembershipPreferenceSchema } from '../types/preferences';

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

const listMemberships = async (): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.listMemberships();

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load memberships.'),
    };
  }
};

const listSuperadmins = async (): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.listSuperadmins();

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load superadmins.'),
    };
  }
};

const fetchMembershipsByTenantId = async (
  tenantId: number,
): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.fetchMembershipsByTenantId(tenantId);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load memberships for tenant.'),
    };
  }
};

const createMembership = async (
  membership: MembershipCreateInput,
): Promise<MembershipServiceResult<Membership>> => {
  try {
    const data = await membershipRepository.createMembership(membership);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to create membership.'),
    };
  }
};

const updateMembership = async (
  membership: MembershipUpdateInput,
): Promise<MembershipServiceResult<Membership>> => {
  try {
    const data = await membershipRepository.updateMembership(membership);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to update membership.'),
    };
  }
};

const deleteMembership = async (
  membership: MembershipDeleteInput,
): Promise<MembershipServiceResult<null>> => {
  try {
    await membershipRepository.deleteMembership(membership);

    return {
      success: true,
      data: null,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to delete membership.'),
    };
  }
};

const getTenantAdmins = async (
  tenantId: number,
): Promise<MembershipServiceResult<Membership[]>> => {
  try {
    const data = await membershipRepository.getTenantAdmins(tenantId);

    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: getErrorMessage(error, 'Failed to load tenant admins.'),
    };
  }
};

const updateMembershipPreference = async (payload: {
  membershipId: number;
  preference: MembershipPreferenceSchema;
}): Promise<MembershipServiceResult<any>> => {
  try {
    const data = await membershipRepository.updateMembershipPreference(payload);
    return {
      success: true,
      data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update membership preference.',
    };
  }
};

export const membershipService = {
  deleteMembership,
  listMemberships,
  listSuperadmins,
  createMembership,
  updateMembership,
  getTenantAdmins,
  fetchMembershipsByTenantId,
  updateMembershipPreference,
};
