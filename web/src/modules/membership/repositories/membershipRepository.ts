import { supabase } from 'src/boot/supabase'

export type Membership = {
  id: number
  email: string
  tenant_id: number | null
  role: string
  is_active: boolean
  created_at?: string
  updated_at?: string
}

export type MembershipCreateInput = {
  tenant_id: number | null
  email: string
  role: string
  is_active: boolean
}

export type MembershipUpdateInput = {
  id: number
  tenant_id?: number | null
  email?: string
  role?: string
  is_active?: boolean
}

export type MembershipDeleteInput = {
  id: number
}

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
    Pick<MembershipUpdateInput, 'tenant_id' | 'email' | 'role' | 'is_active'>
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

export const membershipRepository = {
  listMemberships,
  listSuperadmins,
  createMembership,
  updateMembership,
  deleteMembership,
  getTenantAdmins,
  fetchMembershipsByTenantId,
}
