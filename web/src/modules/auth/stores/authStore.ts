import { acceptHMRUpdate, defineStore } from 'pinia';
import { computed, ref } from 'vue';

import { supabase } from 'src/boot/supabase';
import type { AuthScope } from '../composables/useOAuthLogin';
import type { AccessRole } from '../guards/accessGuard';
import { clearTenantWorkspaceStorage, useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useTenantPreferenceStore } from 'src/modules/tenant/stores/tenantPreferenceStore';
import { useMembershipPreferenceStore } from 'src/modules/membership/stores/membershipPreferenceStore';

export interface AuthUserSnapshot {
  id: string;
  email: string;
  fullName: string | null;
  avatarUrl: string | null;
  provider: string | null;
}

export interface AuthMemberSnapshot {
  id: number;
  email: string;
  role: AccessRole;
  actorType: 'membership' | 'customer_group_member';
  name: string | null;
  tenantId: number | null;
  customerGroupId: number | null;
  isActive: boolean;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface AuthTenantSnapshot {
  id: number;
  name: string;
  slug: string;
  isActive: boolean;
}

export interface AuthCustomerGroupSnapshot {
  id: number;
  name: string;
  isActive: boolean;
  accentColor: string | null;
}

export interface AuthAccessSnapshot {
  scope: AuthScope;
  matchedRole: AuthMemberSnapshot['role'];
  user: AuthUserSnapshot;
  member: AuthMemberSnapshot;
  tenant: AuthTenantSnapshot | null;
  customerGroup: AuthCustomerGroupSnapshot | null;
  activeModuleKeys: string[];
  effectiveGrants: Array<{ module_key: string; action: string }>;
  tenantRoleId: number | null;
  isAdmin: boolean;
  permissionVersion: number | null;
  savedAt: string;
}

type StoredAuthAccess = AuthAccessSnapshot & {
  schemaVersion: 4;
};

const STORAGE_KEY = 'brandwala.auth.access.v4';

const readStorage = (): StoredAuthAccess | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY);
  if (!rawValue) {
    return null;
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<StoredAuthAccess>;

    if (
      parsed?.schemaVersion !== 4 ||
      !parsed?.scope ||
      !parsed?.matchedRole ||
      !parsed?.user ||
      !parsed?.member ||
      !Array.isArray(parsed?.activeModuleKeys) ||
      !Array.isArray(parsed?.effectiveGrants)
    ) {
      return null;
    }

    return parsed as StoredAuthAccess;
  } catch {
    return null;
  }
};

const writeStorage = (snapshot: StoredAuthAccess | null) => {
  if (typeof window === 'undefined') {
    return;
  }

  if (!snapshot) {
    window.localStorage.removeItem(STORAGE_KEY);
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot));
};

export const useAuthStore = defineStore('auth', () => {
  const snapshot = ref<StoredAuthAccess | null>(readStorage());
  const tenantStore = useTenantStore();

  let lastFreshnessCheckAt: number | null = null;
  const FRESHNESS_TTL_MS = 60_000;

  const access = computed(() => snapshot.value);
  const user = computed(() => snapshot.value?.user ?? null);
  const member = computed(() => snapshot.value?.member ?? null);
  const tenant = computed(() => snapshot.value?.tenant ?? null);
  const selectedTenant = computed(() =>
    snapshot.value?.scope === 'app' ? tenantStore.selectedTenant : (snapshot.value?.tenant ?? null),
  );
  const availableAdminTenants = computed(() => tenantStore.availableAdminTenants);
  const customerGroup = computed(() => snapshot.value?.customerGroup ?? null);
  const activeModuleKeys = computed(() => snapshot.value?.activeModuleKeys ?? []);
  const effectiveGrants = computed(() => snapshot.value?.effectiveGrants ?? []);
  const tenantRoleId = computed(() => snapshot.value?.tenantRoleId ?? null);
  const isAdmin = computed(() => snapshot.value?.isAdmin ?? false);
  const scope = computed(() => snapshot.value?.scope ?? null);
  const matchedRole = computed(() => snapshot.value?.matchedRole ?? null);
  const isAuthenticated = computed(() => Boolean(snapshot.value?.user));
  const hasAccess = computed(() => Boolean(snapshot.value?.member?.isActive));
  const actorId = computed(() => snapshot.value?.member?.id ?? null);
  const actorType = computed(() => snapshot.value?.member?.actorType ?? null);
  const membershipId = computed(() =>
    snapshot.value?.member?.actorType === 'membership' ? snapshot.value.member.id : null,
  );
  const customerGroupMemberId = computed(() =>
    snapshot.value?.member?.actorType === 'customer_group_member' ? snapshot.value.member.id : null,
  );
  const tenantId = computed(
    () =>
      selectedTenant.value?.id ??
      snapshot.value?.tenant?.id ??
      snapshot.value?.member?.tenantId ??
      null,
  );
  const tenantSlug = computed(
    () => selectedTenant.value?.slug ?? snapshot.value?.tenant?.slug ?? null,
  );
  const customerGroupId = computed(
    () => snapshot.value?.customerGroup?.id ?? snapshot.value?.member?.customerGroupId ?? null,
  );

  const permissionVersion = computed(() => snapshot.value?.permissionVersion ?? null);

  const saveAccess = (nextAccess: Omit<StoredAuthAccess, 'schemaVersion'>) => {
    snapshot.value = {
      ...nextAccess,
      schemaVersion: 4,
    };
    writeStorage(snapshot.value);
  };

  const silentRebootstrap = async () => {
    if (!snapshot.value || !snapshot.value.user?.email) return false;
    const email = snapshot.value.user.email;
    const scopeVal = snapshot.value.scope;

    try {
      if (scopeVal === 'app') {
        const tenantIdVal = snapshot.value.tenant?.id ?? null;
        const membershipIdVal = snapshot.value.member?.id ?? null;
        const { data, error } = await supabase.rpc('get_app_bootstrap_context', {
          p_email: email,
          p_tenant_id: tenantIdVal,
          p_membership_id: membershipIdVal,
        });
        if (error || !data) return false;
        const bootstrap = Array.isArray(data) ? data[0] : data;
        if (!bootstrap) return false;

        useTenantPreferenceStore().setPreference(bootstrap.tenant_id, bootstrap.tenant_preference);
        useMembershipPreferenceStore().setPreference(
          bootstrap.member_id,
          bootstrap.member_preference,
        );

        saveAccess({
          scope: 'app',
          matchedRole: bootstrap.member_role,
          user: snapshot.value.user,
          member: {
            ...snapshot.value.member,
            role: bootstrap.member_role,
            isActive: Boolean(bootstrap.member_is_active),
            tenantId: bootstrap.tenant_id,
          },
          tenant: {
            id: bootstrap.tenant_id,
            name: bootstrap.tenant_name,
            slug: bootstrap.tenant_slug,
            isActive: Boolean(bootstrap.tenant_is_active),
          },
          customerGroup: null,
          activeModuleKeys: bootstrap.active_module_keys || [],
          effectiveGrants: bootstrap.effective_grants || [],
          tenantRoleId: bootstrap.tenant_role_id ?? null,
          isAdmin: Boolean(bootstrap.is_admin),
          permissionVersion: bootstrap.permission_version ?? null,
          savedAt: new Date().toISOString(),
        });
        lastFreshnessCheckAt = null;
        return true;
      } else if (scopeVal === 'shop') {
        const tenantIdVal = snapshot.value.tenant?.id ?? null;
        const memberIdVal = snapshot.value.member?.id ?? null;
        const { data, error } = await supabase.rpc('get_shop_bootstrap_context', {
          p_email: email,
          p_tenant_id: tenantIdVal,
          p_customer_group_member_id: memberIdVal,
        });
        if (error || !data) return false;
        const bootstrap = Array.isArray(data) ? data[0] : data;
        if (!bootstrap) return false;

        saveAccess({
          scope: 'shop',
          matchedRole: bootstrap.member_role,
          user: snapshot.value.user,
          member: {
            ...snapshot.value.member,
            role: bootstrap.member_role,
            name: bootstrap.member_name ?? null,
            isActive: Boolean(bootstrap.member_is_active),
            tenantId: bootstrap.tenant_id,
            customerGroupId: bootstrap.customer_group_id,
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
          savedAt: new Date().toISOString(),
        });
        lastFreshnessCheckAt = null;
        return true;
      } else if (scopeVal === 'investor') {
        const tenantIdVal = snapshot.value.tenant?.id ?? null;
        const { data, error } = await supabase.rpc('get_investor_bootstrap_context', {
          p_tenant_id: tenantIdVal,
        });
        if (error || !data) return false;
        const bootstrap = data;
        if (!bootstrap || !bootstrap.authenticated || !bootstrap.investor_account) return false;

        saveAccess({
          scope: 'investor',
          matchedRole: 'investor_portal',
          user: snapshot.value.user,
          member: {
            id: bootstrap.investor_account.investor_id,
            email: bootstrap.investor_account.email.trim().toLowerCase(),
            role: 'investor_portal',
            actorType: 'membership',
            name: null,
            tenantId: bootstrap.tenant.id,
            customerGroupId: null,
            isActive: Boolean(bootstrap.investor_account.is_active ?? true),
            createdAt: null,
            updatedAt: null,
          },
          tenant: {
            id: bootstrap.tenant.id,
            name: bootstrap.tenant.name,
            slug: bootstrap.tenant.slug,
            isActive: bootstrap.tenant.is_active ?? true,
          },
          customerGroup: null,
          activeModuleKeys: bootstrap.module_keys || [],
          effectiveGrants: [{ module_key: 'investor_portal', action: 'view' }],
          tenantRoleId: null,
          isAdmin: false,
          permissionVersion: bootstrap.permission_version ?? null,
          savedAt: new Date().toISOString(),
        });
        lastFreshnessCheckAt = null;
        return true;
      }
    } catch (e) {
      console.error('[authStore] silent re-bootstrap error', e);
    }
    return false;
  };

  const checkFreshness = async () => {
    if (!tenantId.value) return;
    if (lastFreshnessCheckAt !== null && Date.now() - lastFreshnessCheckAt < FRESHNESS_TTL_MS) {
      return;
    }
    try {
      const { data, error } = await supabase.rpc('get_tenant_permission_version', {
        p_tenant_id: tenantId.value,
      });
      lastFreshnessCheckAt = Date.now();
      if (!error && data !== null && Number(data) !== permissionVersion.value) {
        console.log(
          '[authStore] Permission version mismatch. Re-bootstrapping silently...',
          data,
          permissionVersion.value,
        );
        await silentRebootstrap();
      }
    } catch (e) {
      console.error('[authStore] Freshness check failed', e);
    }
  };

  const clearAccess = () => {
    snapshot.value = null;
    writeStorage(null);
    clearTenantWorkspaceStorage();
    useTenantPreferenceStore().clear();
    useMembershipPreferenceStore().clear();
  };

  return {
    access,
    clearAccess,
    customerGroup,
    customerGroupMemberId,
    customerGroupId,
    hasAccess,
    isAuthenticated,
    member,
    actorId,
    actorType,
    availableAdminTenants,
    membershipId,
    matchedRole,
    saveAccess,
    selectedTenant,
    scope,
    tenant,
    tenantId,
    tenantSlug,
    user,
    activeModuleKeys,
    effectiveGrants,
    tenantRoleId,
    isAdmin,
    permissionVersion,
    silentRebootstrap,
    checkFreshness,
  };
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useAuthStore, import.meta.hot));
}
