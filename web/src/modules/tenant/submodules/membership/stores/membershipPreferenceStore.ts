import { defineStore } from 'pinia';
import { supabase } from 'src/boot/supabase';
import { membershipService } from '../services/membershipService';
import type { MembershipPreferenceSchema } from '../types/preferences';
import { parseMembershipPreference, setPreferencePath } from '../utils/preferenceUtils';

const MEMBERSHIP_PREF_STORAGE_KEY = 'brandwala.membership.preference.v1';

interface StoredMembershipPreference {
  membershipId: number;
  preference: MembershipPreferenceSchema;
}

const readStoredMembershipPreference = (): StoredMembershipPreference | null => {
  if (typeof window === 'undefined') return null;
  const raw = window.localStorage.getItem(MEMBERSHIP_PREF_STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.membershipId === 'number' && parsed.preference) {
      return parsed;
    }
  } catch {
    // ignore
  }
  return null;
};

const writeStoredMembershipPreference = (data: StoredMembershipPreference | null) => {
  if (typeof window === 'undefined') return;
  if (!data) {
    window.localStorage.removeItem(MEMBERSHIP_PREF_STORAGE_KEY);
  } else {
    window.localStorage.setItem(MEMBERSHIP_PREF_STORAGE_KEY, JSON.stringify(data));
  }
};

export const useMembershipPreferenceStore = defineStore('membershipPreference', {
  state: () => {
    const stored = readStoredMembershipPreference();
    return {
      preference: stored ? stored.preference : ({} as MembershipPreferenceSchema),
      loadedMembershipId: stored ? stored.membershipId : (null as number | null),
      loading: false,
      error: null as string | null,
    };
  },

  actions: {
    setPreference(membershipId: number, raw: unknown) {
      this.preference = parseMembershipPreference(raw);
      this.loadedMembershipId = membershipId;
      this.error = null;
      writeStoredMembershipPreference({ membershipId, preference: this.preference });
    },

    async ensureLoaded(membershipId: number, email?: string | null, tenantId?: number | null) {
      if (this.loadedMembershipId === membershipId) {
        return { success: true as const };
      }

      this.loading = true;
      this.error = null;

      try {
        const { data, error } = await supabase.rpc('get_app_bootstrap_context', {
          p_email: email ?? undefined,
          p_tenant_id: tenantId ?? undefined,
          p_membership_id: membershipId,
        });

        if (error) {
          this.error = error.message;
          return { success: false as const, error: this.error };
        }

        const bootstrap = Array.isArray(data) ? data[0] : data;
        if (!bootstrap?.member_id) {
          this.error = 'Failed to load membership preferences.';
          return { success: false as const, error: this.error };
        }

        this.setPreference(bootstrap.member_id, bootstrap.member_preference);
        return { success: true as const };
      } finally {
        this.loading = false;
      }
    },

    patchPreferencePath(membershipId: number, path: readonly string[], value: unknown) {
      this.preference = setPreferencePath(this.preference, path, value);
      this.loadedMembershipId = membershipId;
      writeStoredMembershipPreference({ membershipId, preference: this.preference });
    },

    async savePreference(membershipId: number) {
      this.loading = true;
      this.error = null;

      try {
        const result = await membershipService.updateMembershipPreference({
          membershipId,
          preference: this.preference,
        });

        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to save membership preferences.';
          return { success: false as const, error: this.error };
        }

        this.setPreference(membershipId, result.data.preference);
        return { success: true as const, data: result.data };
      } finally {
        this.loading = false;
      }
    },

    clear() {
      this.preference = {};
      this.loadedMembershipId = null;
      this.loading = false;
      this.error = null;
      writeStoredMembershipPreference(null);
    },
  },
});
