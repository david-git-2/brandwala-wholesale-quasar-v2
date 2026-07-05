import { supabase } from 'src/boot/supabase'
import type {
  Membership,
  MembershipCreateInput,
  MembershipDeleteInput,
  MembershipUpdateInput,
} from '../types'
import type { MembershipPreferenceSchema } from '../types/preferences'

const listMemberships = async (): Promise<Membership[]> => {
  const { data, error } = await supabase
    .from('memberships')
    .select('*')

  if (error) {
    throw error
  }

  return (data as Membership[] | null) ?? []
}

const listSuperadmins = async (): Promise<Membership[]> => {
  const { data, error } = await supabase
    .from('memberships')
    .select('*')
    .eq('role', 'superadmin')
    .order('created_at', { ascending: false })

  if (error) {
    throw error
  }

  return (data as Membership[] | null) ?? []
}

const fetchMembershipsByTenantId = async (tenantId: number): Promise<Membership[]> => {
  const { data, error } = await supabase
    .from('memberships')
    .select('*')
    .eq('tenant_id', tenantId)

  if (error) {
    throw error
  }

  return (data as Membership[] | null) ?? []
}

const createMembership = async (
  membership: MembershipCreateInput
): Promise<Membership> => {
  const { data, error } = await supabase
    .from('memberships')
    .insert([
      {
        tenant_id: membership.tenant_id,
        email: membership.email,
        role: membership.role,
        is_active: membership.is_active,
        investor_id: membership.investor_id || null,
      },
    ])
    .select()

  if (error) {
    throw error
  }

  const createdMembership = Array.isArray(data) ? data[0] : data

  if (!createdMembership) {
    throw new Error('Membership was not created.')
  }

  return createdMembership as Membership
}

const updateMembership = async (
  membership: MembershipUpdateInput
): Promise<Membership> => {
  const updatePayload: Partial<
    Pick<MembershipUpdateInput, 'tenant_id' | 'email' | 'role' | 'is_active' | 'investor_id'>
  > = {}

  if (membership.tenant_id !== undefined) {
    updatePayload.tenant_id = membership.tenant_id
  }

  if (membership.email !== undefined) {
    updatePayload.email = membership.email
  }

  if (membership.role !== undefined) {
    updatePayload.role = membership.role
  }

  if (membership.is_active !== undefined) {
    updatePayload.is_active = membership.is_active
  }

  if (membership.investor_id !== undefined) {
    updatePayload.investor_id = membership.investor_id
  }

  const { data, error } = await supabase
    .from('memberships')
    .update(updatePayload)
    .eq('id', membership.id)
    .select()

  if (error) {
    throw error
  }

  const updatedMembership = Array.isArray(data) ? data[0] : data
  if (!updatedMembership) {
    throw new Error('Membership was not updated.')
  }

  return updatedMembership as Membership
}

const deleteMembership = async (
  membership: MembershipDeleteInput
): Promise<void> => {
  const { error } = await supabase
    .from('memberships')
    .delete()
    .eq('id', membership.id)

  if (error) {
    throw error
  }
}

const getTenantAdmins = async (tenantId: number): Promise<Membership[]> => {
  const { data, error } = await supabase
    .from('memberships')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('role', 'admin')

   if (error) {
    throw error
  }

  return (data as Membership[] | null) ?? []
}

const updateMembershipPreference = async (payload: {
  membershipId: number
  preference: MembershipPreferenceSchema
}) => {
  const { data, error } = await supabase.rpc('update_membership_preference_for_self', {
    p_membership_id: payload.membershipId,
    p_preference: payload.preference as any,
  })

  if (error) {
    throw error
  }

  const updatedMembership = Array.isArray(data) ? data[0] : data
  if (!updatedMembership) {
    throw new Error('Membership preference was not updated.')
  }

  return updatedMembership
}

export const membershipRepository = {
  listMemberships,
  listSuperadmins,
  createMembership,
  updateMembership,
  deleteMembership,
  getTenantAdmins,
  fetchMembershipsByTenantId,
  updateMembershipPreference,
}
