import { defineStore } from 'pinia';
import { thriftSettingsRepository } from '../repositories/thriftSettingsRepository';
import type { ThriftSettings, ThriftSettingsInput } from '../types';

export const useThriftSettingsStore = defineStore('thriftSettings', {
  state: () => ({
    settings: null as ThriftSettings | null,
    loading: false,
    error: null as string | null,
  }),

  getters: {
    defaultOriginUnitPrice: (state): number =>
      state.settings?.default_origin_unit_price ?? 0,
    handTagUnitCost: (state): number =>
      state.settings?.hand_tag_unit_cost ?? 0,
    handTagUnitCurrencyId: (state): number | null =>
      state.settings?.hand_tag_unit_currency_id ?? null,
    stickerUnitCost: (state): number =>
      state.settings?.sticker_unit_cost ?? 0,
    stickerUnitCurrencyId: (state): number | null =>
      state.settings?.sticker_unit_currency_id ?? null,
    opsCostSettingsForEngine: (state) => ({
      hand_tag_unit_cost: state.settings?.hand_tag_unit_cost ?? 0,
      sticker_unit_cost: state.settings?.sticker_unit_cost ?? 0,
    }),
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

    async saveSettings(tenantId: number, input: ThriftSettingsInput) {
      this.loading = true;
      this.error = null;
      try {
        this.settings = await thriftSettingsRepository.upsertSettings(tenantId, input);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to save settings';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
