import type { Enums, Tables } from 'src/types/supabase'

export type Tenant = Tables<'tenants'>
export type TenantCreateInput = Pick<Tenant, 'name' | 'slug' | 'public_domain' | 'is_active'>
export type TenantUpdateInput = {
  id: Tenant['id']
  name: Tenant['name']
  slug: Tenant['slug']
  public_domain: Tenant['public_domain']
  is_active: Tenant['is_active']
}
export type TenantDeleteInput = Pick<Tenant, 'id'>

export type TenantModule = Tables<'tenant_modules'>
export type TenantModuleCreateInput = Pick<TenantModule, 'tenant_id' | 'module_key' | 'is_active'>
export type TenantModuleUpdateInput = {
  id: TenantModule['id']
  tenant_id?: TenantModule['tenant_id']
  module_key?: TenantModule['module_key']
  is_active?: TenantModule['is_active']
}
export type TenantModuleDeleteInput = Pick<TenantModule, 'id'>

export type CustomerGroup = Tables<'customer_groups'>
export type CustomerGroupCreateInput = Pick<
  CustomerGroup,
  'tenant_id' | 'name' | 'is_active' | 'accent_color'
>
export type CustomerGroupUpdateInput = {
  id: CustomerGroup['id']
  tenant_id?: CustomerGroup['tenant_id']
  name?: CustomerGroup['name']
  is_active?: CustomerGroup['is_active']
  accent_color?: CustomerGroup['accent_color']
}
export type CustomerGroupDeleteInput = Pick<CustomerGroup, 'id'>

export type CustomerGroupMember = Tables<'customer_group_members'>
export type CustomerGroupRole = Enums<'customer_group_role'>
export type CustomerGroupMemberCreateInput = Pick<
  CustomerGroupMember,
  'customer_group_id' | 'name' | 'email' | 'role' | 'is_active'
>
export type CustomerGroupMemberUpdateInput = {
  id: CustomerGroupMember['id']
  customer_group_id?: CustomerGroupMember['customer_group_id']
  name?: CustomerGroupMember['name']
  email?: CustomerGroupMember['email']
  role?: CustomerGroupMember['role']
  is_active?: CustomerGroupMember['is_active']
}
export type CustomerGroupMemberDeleteInput = Pick<CustomerGroupMember, 'id'>

export interface TenantServiceResult<T = void> {
  success: boolean
  data?: T
  error?: string
}

export interface TenantStoreState {
  items: Tenant[]
  loading: boolean
  error: string | null
}
