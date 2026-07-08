import { defineStore } from 'pinia';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { tenantService } from '../services/tenantService';
import { useTenantStore } from './tenantStore';
import { parseTenantPreference } from '../utils/tenantPreferenceUtils';
import type { TenantPreferenceSchema } from '../types/preferences';

export const useTenantPreferenceStore = defineStore('tenantPreference', {
  state: () => ({
    preference: {} as TenantPreferenceSchema,
    loadedTenantId: null as number | null,
    loading: false,
    error: null as string | null,
  }),

  getters: {
    thriftDefaultPurchaseCurrencyId(state): number | null {
      const value = state.preference.thrift?.default_purchase_currency;
      return typeof value === 'number' ? value : null;
    },

    thriftDefaultCostCurrencyId(state): number | null {
      const value = state.preference.thrift?.default_cost_currency;
      return typeof value === 'number' ? value : null;
    },
  },

  actions: {
    setPreference(tenantId: number, raw: unknown) {
      this.preference = parseTenantPreference(raw);
      this.loadedTenantId = tenantId;
      this.error = null;
    },

    async ensureLoaded(
      tenantId: number,
      email?: string | null,
      role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null,
    ) {
      if (this.loadedTenantId === tenantId) {
        return;
      }

      this.loading = true;
      this.error = null;

      try {
        const payload: {
          tenantId: number;
          email?: string | null;
          role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | null;
        } = { tenantId };

        if (email !== undefined) {
          payload.email = email;
        }

        if (role !== undefined) {
          payload.role = role;
        }

        const result = await tenantService.getTenantDetailsByMembership(payload);

        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to load tenant preferences.';
          return;
        }

        this.setPreference(tenantId, result.data.preference);
      } finally {
        this.loading = false;
      }
    },

    async savePreference(tenantId: number, preference: TenantPreferenceSchema) {
      this.loading = true;
      this.error = null;

      try {
        const result = await tenantService.updateTenantPreference({
          tenantId,
          preference,
        });

        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to save tenant preferences.';
          return { success: false as const, error: this.error };
        }

        this.setPreference(tenantId, result.data.preference);

        const tenantStore = useTenantStore();
        const index = tenantStore.items.findIndex((item) => item.id === tenantId);

        if (index >= 0) {
          tenantStore.items.splice(index, 1, result.data);
        }

        const adminIndex = tenantStore.availableAdminTenants.findIndex(
          (item) => item.id === tenantId,
        );

        if (adminIndex >= 0) {
          tenantStore.availableAdminTenants.splice(adminIndex, 1, result.data);
        }

        const authStore = useAuthStore();

        if (authStore.tenantId === tenantId) {
          this.setPreference(tenantId, result.data.preference);
        }

        return { success: true as const, data: result.data };
      } finally {
        this.loading = false;
      }
    },

    clear() {
      this.preference = {};
      this.loadedTenantId = null;
      this.loading = false;
      this.error = null;
    },
  },
});
