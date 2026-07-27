import { supabase } from 'src/boot/supabase';

export const accessControlRepository = {
  async fetchTenantModules(tenantId: number) {
    const { data, error } = await supabase
      .from('tenant_modules')
      .select('*')
      .eq('tenant_id', tenantId);
    if (error) throw error;
    return data || [];
  },

  async fetchCatalogModules() {
    const { data, error } = await supabase.from('modules').select('*');
    if (error) throw error;
    return data || [];
  },

  async fetchTenantRoles(tenantId: number, scope: 'app' | 'shop') {
    const { data, error } = await supabase.rpc('list_tenant_roles', {
      p_tenant_id: tenantId,
      p_scope: scope,
    });
    if (error) throw error;
    return data || [];
  },

  async fetchMembershipOverrideIds(tenantId: number) {
    const { data, error } = await supabase.rpc('list_membership_ids_with_overrides', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return new Set((data || []).map((row: any) => row.membership_id as number));
  },

  async fetchTenantMembers(tenantId: number) {
    const { data, error } = await supabase
      .from('memberships')
      .select('*')
      .eq('tenant_id', tenantId);
    if (error) throw error;
    return data || [];
  },

  async fetchCustomerGroups(tenantId: number) {
    const { data, error } = await supabase
      .from('customer_groups')
      .select('*')
      .eq('tenant_id', tenantId);
    if (error) throw error;
    return data || [];
  },

  async fetchCustomerGroupMembers(groupId: number) {
    const { data, error } = await supabase
      .from('customer_group_members')
      .select('*')
      .eq('customer_group_id', groupId);
    if (error) throw error;
    return data || [];
  },

  async fetchBillingProfiles(tenantId: number) {
    const { data, error } = await supabase
      .from('billing_profiles')
      .select('*')
      .eq('tenant_id', tenantId);
    if (error) throw error;
    return data || [];
  },

  async fetchInvestors() {
    const { data, error } = await supabase.from('investors').select('id, name');
    if (error) throw error;
    return data || [];
  },

  async fetchCgmOverrideIds(groupId: number) {
    const { data, error } = await supabase.rpc('list_cgm_ids_with_overrides', {
      p_customer_group_id: groupId,
    });
    if (error) throw error;
    return new Set((data || []).map((row: any) => row.customer_group_member_id as number));
  },
};
