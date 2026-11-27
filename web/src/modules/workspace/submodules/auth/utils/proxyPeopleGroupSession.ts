import { supabase } from 'src/boot/supabase';
import { mapProxyRoleToAccessRole } from '../guards/accessGuard';
import type { AuthAccessSnapshot, AuthUserSnapshot } from '../stores/authStore';

export type ProxyLoginGroupRow = {
  has_match: boolean;
  matched_role: string;
  member_id: number;
  member_name: string | null;
  member_email: string;
  member_tenant_id: number | null;
  people_group_id: number;
  people_group_name: string;
  people_group_type: string;
  member_is_active: boolean;
  people_group_is_active: boolean;
  member_created_at: string | null;
  member_updated_at: string | null;
};

const normalizeRows = (data: unknown): ProxyLoginGroupRow[] => {
  const rows = Array.isArray(data) ? data : data ? [data] : [];
  return rows.filter(
    (row): row is ProxyLoginGroupRow =>
      Boolean(
        row &&
          typeof row === 'object' &&
          typeof (row as ProxyLoginGroupRow).member_id === 'number' &&
          typeof (row as ProxyLoginGroupRow).people_group_id === 'number' &&
          (row as ProxyLoginGroupRow).has_match !== false,
      ),
  );
};

export const listProxyLoginGroups = async (
  email: string,
  tenantId: number,
): Promise<ProxyLoginGroupRow[]> => {
  const { data, error } = await supabase.rpc('check_proxy_login_access', {
    p_email: email,
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }

  return normalizeRows(data);
};

export const buildProxyAccessFromBootstrap = (
  user: AuthUserSnapshot,
  bootstrap: {
    member_id: number;
    member_name: string | null;
    member_email: string | null;
    member_role: string;
    member_is_active: boolean;
    people_group_id: number;
    people_group_name: string;
    people_group_type: string;
    people_group_is_active: boolean;
    tenant_id: number;
    tenant_name: string;
    tenant_slug: string;
    tenant_is_active: boolean;
    active_module_keys: string[] | null;
    effective_grants: Array<{ module_key: string; action: string }>;
    tenant_role_id: number | null;
    is_admin: boolean;
    permission_version: number | null;
  },
  createdAt: string | null,
  updatedAt: string | null,
): Omit<AuthAccessSnapshot, 'savedAt'> | null => {
  const proxyRole = mapProxyRoleToAccessRole(bootstrap.people_group_type, bootstrap.member_role);
  if (!proxyRole) {
    return null;
  }

  return {
    scope: 'proxy',
    matchedRole: proxyRole,
    user,
    member: {
      id: bootstrap.member_id,
      email: bootstrap.member_email?.trim().toLowerCase() ?? user.email,
      role: proxyRole,
      actorType: 'pp_people_group_member',
      name: bootstrap.member_name ?? null,
      tenantId: bootstrap.tenant_id,
      customerGroupId: bootstrap.people_group_id,
      isActive: Boolean(bootstrap.member_is_active),
      createdAt,
      updatedAt,
    },
    tenant: {
      id: bootstrap.tenant_id,
      name: bootstrap.tenant_name,
      slug: bootstrap.tenant_slug,
      isActive: Boolean(bootstrap.tenant_is_active),
    },
    customerGroup: {
      id: bootstrap.people_group_id,
      name: bootstrap.people_group_name,
      isActive: Boolean(bootstrap.people_group_is_active),
      accentColor: null,
    },
    activeModuleKeys: bootstrap.active_module_keys || [],
    effectiveGrants: bootstrap.effective_grants || [],
    tenantRoleId: bootstrap.tenant_role_id ?? null,
    isAdmin: Boolean(bootstrap.is_admin),
    permissionVersion: bootstrap.permission_version ?? null,
  };
};

export const bootstrapProxyPeopleGroup = async (params: {
  user: AuthUserSnapshot;
  email: string;
  tenantId: number;
  memberId: number;
  createdAt?: string | null;
  updatedAt?: string | null;
}): Promise<Omit<AuthAccessSnapshot, 'savedAt'> | null> => {
  const { data, error } = await supabase.rpc('get_proxy_bootstrap_context', {
    p_email: params.email,
    p_tenant_id: params.tenantId,
    p_people_group_member_id: params.memberId,
  });

  if (error) {
    throw error;
  }

  const bootstrap = Array.isArray(data) ? data[0] : data;
  if (
    !bootstrap ||
    bootstrap.member_id === null ||
    bootstrap.people_group_id === null ||
    bootstrap.tenant_id === null ||
    !bootstrap.people_group_name ||
    !bootstrap.tenant_name ||
    !bootstrap.tenant_slug
  ) {
    return null;
  }

  return buildProxyAccessFromBootstrap(
    params.user,
    {
      ...bootstrap,
      member_id: bootstrap.member_id,
      people_group_id: bootstrap.people_group_id,
      tenant_id: bootstrap.tenant_id,
      member_role: bootstrap.member_role ?? '',
      people_group_type: bootstrap.people_group_type ?? '',
      member_is_active: Boolean(bootstrap.member_is_active),
      people_group_is_active: Boolean(bootstrap.people_group_is_active),
      tenant_is_active: Boolean(bootstrap.tenant_is_active),
      effective_grants: (bootstrap.effective_grants || []) as Array<{
        module_key: string;
        action: string;
      }>,
    },
    params.createdAt ?? null,
    params.updatedAt ?? null,
  );
};