import { supabase } from 'src/boot/supabase';
import { mapShopRoleToAccessRole } from '../guards/accessGuard';
import type {
  AuthAccessSnapshot,
  AuthUserSnapshot,
} from '../stores/authStore';
import { writeLastShopCustomerGroupId } from './shopSelectedGroupStorage';

export type ShopLoginGroupRow = {
  has_match: boolean;
  matched_role: string;
  member_id: number;
  member_name: string | null;
  member_email: string;
  member_tenant_id: number | null;
  customer_group_id: number;
  customer_group_name: string;
  member_is_active: boolean;
  customer_group_is_active: boolean;
  member_created_at: string | null;
  member_updated_at: string | null;
};

const normalizeRows = (data: unknown): ShopLoginGroupRow[] => {
  const rows = Array.isArray(data) ? data : data ? [data] : [];
  return rows.filter(
    (row): row is ShopLoginGroupRow =>
      Boolean(
        row &&
          typeof row === 'object' &&
          typeof (row as ShopLoginGroupRow).member_id === 'number' &&
          typeof (row as ShopLoginGroupRow).customer_group_id === 'number' &&
          (row as ShopLoginGroupRow).has_match !== false,
      ),
  );
};

export const listShopLoginGroups = async (
  email: string,
  tenantId: number,
): Promise<ShopLoginGroupRow[]> => {
  const { data, error } = await supabase.rpc('check_shop_login_access', {
    p_email: email,
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }

  return normalizeRows(data);
};

export const buildShopAccessFromBootstrap = (
  user: AuthUserSnapshot,
  bootstrap: {
    member_id: number;
    member_name: string | null;
    member_email: string | null;
    member_role: string;
    member_is_active: boolean;
    customer_group_id: number;
    customer_group_name: string;
    customer_group_is_active: boolean;
    customer_group_accent_color: string | null;
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
  const shopRole = mapShopRoleToAccessRole(bootstrap.member_role);
  if (!shopRole) {
    return null;
  }

  return {
    scope: 'shop',
    matchedRole: shopRole,
    user,
    member: {
      id: bootstrap.member_id,
      email: bootstrap.member_email?.trim().toLowerCase() ?? user.email,
      role: shopRole,
      actorType: 'customer_group_member',
      name: bootstrap.member_name ?? null,
      tenantId: bootstrap.tenant_id,
      customerGroupId: bootstrap.customer_group_id,
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
      id: bootstrap.customer_group_id,
      name: bootstrap.customer_group_name,
      isActive: Boolean(bootstrap.customer_group_is_active),
      accentColor: bootstrap.customer_group_accent_color?.trim() || null,
    },
    activeModuleKeys: bootstrap.active_module_keys || [],
    effectiveGrants: bootstrap.effective_grants || [],
    tenantRoleId: bootstrap.tenant_role_id ?? null,
    isAdmin: Boolean(bootstrap.is_admin),
    permissionVersion: bootstrap.permission_version ?? null,
  };
};

export const bootstrapShopCustomerGroup = async (params: {
  user: AuthUserSnapshot;
  email: string;
  tenantId: number;
  memberId: number;
  createdAt?: string | null;
  updatedAt?: string | null;
}): Promise<Omit<AuthAccessSnapshot, 'savedAt'> | null> => {
  const { data, error } = await supabase.rpc('get_shop_bootstrap_context', {
    p_email: params.email,
    p_tenant_id: params.tenantId,
    p_customer_group_member_id: params.memberId,
  });

  if (error) {
    throw error;
  }

  const bootstrap = Array.isArray(data) ? data[0] : data;
  if (
    !bootstrap ||
    bootstrap.member_id === null ||
    bootstrap.customer_group_id === null ||
    bootstrap.tenant_id === null ||
    !bootstrap.customer_group_name ||
    !bootstrap.tenant_name ||
    !bootstrap.tenant_slug
  ) {
    return null;
  }

  const snapshot = buildShopAccessFromBootstrap(
    params.user,
    {
      ...bootstrap,
      member_id: bootstrap.member_id,
      customer_group_id: bootstrap.customer_group_id,
      tenant_id: bootstrap.tenant_id,
      member_role: bootstrap.member_role ?? '',
      member_is_active: Boolean(bootstrap.member_is_active),
      customer_group_is_active: Boolean(bootstrap.customer_group_is_active),
      tenant_is_active: Boolean(bootstrap.tenant_is_active),
      effective_grants: (bootstrap.effective_grants || []) as Array<{
        module_key: string;
        action: string;
      }>,
    },
    params.createdAt ?? null,
    params.updatedAt ?? null,
  );

  if (snapshot?.customerGroup) {
    writeLastShopCustomerGroupId(params.email, params.tenantId, snapshot.customerGroup.id);
  }

  return snapshot;
};
