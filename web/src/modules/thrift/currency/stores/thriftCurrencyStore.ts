import { defineStore } from 'pinia';
import { thriftCurrencyRepository } from '../repositories/thriftCurrencyRepository';
import type { ThriftCurrency } from '../types';

export const useThriftCurrencyStore = defineStore('thriftCurrency', {
  state: () => ({
    currencies: [] as ThriftCurrency[],
    loading: false,
    error: null as string | null,
  }),

  getters: {
    currencyById:
      (state) =>
      (id: number | null | undefined): ThriftCurrency | undefined => {
        if (!id) return undefined;
        return state.currencies.find((c) => c.id === id);
      },
  },

  actions: {
    async loadCurrencies() {
      if (this.currencies.length > 0) return;
      this.loading = true;
      this.error = null;
      try {
        this.currencies = await thriftCurrencyRepository.fetchActiveCurrencies();
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load currencies';
      } finally {
        this.loading = false;
      }
    },
  },
});
