import { defineStore } from 'pinia';
import { thriftSettingsRepository } from '../repositories/thriftSettingsRepository';
import type { ThriftSettings } from '../types';

export const useThriftSettingsStore = defineStore('thriftSettings', {
  state: () => ({
    settings: null as ThriftSettings | null,
    loading: false,
    error: null as string | null,
  }),

  getters: {
    defaultPurchasePriceGbp: (state): number =>
      state.settings?.default_purchase_price_gbp ?? 0,
  },

  actions: {
    async loadSettings(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.settings = await thriftSettingsRepository.fetchSettings(tenantId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load settings';
      } finally {
        this.loading = false;
      }
    },

    async saveSettings(tenantId: number, defaultPurchasePriceGbp: number) {
      this.loading = true;
      this.error = null;
      try {
        this.settings = await thriftSettingsRepository.upsertSettings(
          tenantId,
          defaultPurchasePriceGbp,
        );
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to save settings';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
