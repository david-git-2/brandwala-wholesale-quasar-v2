import { supabase } from 'src/boot/supabase';
import type { AccessRole } from '../guards/accessGuard';

export type AppLoginBundleLogin = {
  matched_role: AccessRole;
  member_id: number;
  member_email: string;
  member_tenant_id: number | null;
  member_is_active: boolean;
  member_created_at: string | null;
  member_updated_at: string | null;
};

export type AppLoginBundleTenant = {
  id: number;
  name: string;
  slug: string;
  public_domain: string | null;
  is_active: boolean;
  parent_id: number | null;
  preference: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
};

export type AppLoginBootstrap = {
  member_id: number;
  member_email: string | null;
  member_role: AccessRole;
  member_is_active: boolean;
  member_preference: Record<string, unknown> | null;
  tenant_id: number;
  tenant_name: string;
  tenant_slug: string;
  tenant_is_active: boolean;
  tenant_preference: Record<string, unknown> | null;
  active_module_keys: string[] | null;
  tenant_role_id: number | null;
  is_admin: boolean;
  effective_grants: Array<{ module_key: string; action: string }>;
  permission_version: number | null;
};

export type AppLoginBundle = {
  has_match: boolean;
  error_code?: string | null;
  login?: AppLoginBundleLogin | null;
  tenants?: AppLoginBundleTenant[];
  workspace_tenant_id?: number | null;
  bootstrap?: AppLoginBootstrap | null;
};

export const appLoginBundleRepository = {
  async fetchBundle(email: string, requestedTenantSlug: string | null): Promise<AppLoginBundle> {
    const { data, error } = await supabase.rpc('get_app_login_bundle', {
      p_email: email,
      p_requested_tenant_slug: requestedTenantSlug?.trim() || null,
    });

    if (error) {
      throw error;
    }

    return (data ?? { has_match: false }) as AppLoginBundle;
  },
};
