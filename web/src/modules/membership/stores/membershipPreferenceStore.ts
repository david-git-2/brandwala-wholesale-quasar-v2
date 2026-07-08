import { defineStore } from 'pinia';
import { supabase } from 'src/boot/supabase';
import { membershipService } from '../services/membershipService';
import type { MembershipPreferenceSchema } from '../types/preferences';
import { parseMembershipPreference, setPreferencePath } from '../utils/preferenceUtils';

export const useMembershipPreferenceStore = defineStore('membershipPreference', {
  state: () => ({
    preference: {} as MembershipPreferenceSchema,
    loadedMembershipId: null as number | null,
    loading: false,
    error: null as string | null,
  }),

  actions: {
    setPreference(membershipId: number, raw: unknown) {
      this.preference = parseMembershipPreference(raw);
      this.loadedMembershipId = membershipId;
      this.error = null;
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
    },
  },
});
