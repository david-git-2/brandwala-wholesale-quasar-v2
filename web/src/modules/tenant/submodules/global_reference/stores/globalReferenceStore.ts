import { defineStore } from 'pinia';
import { supabase } from 'src/boot/supabase';
import type { GlobalCurrency } from '../types';

let currenciesLoadPromise: Promise<GlobalCurrency[]> | null = null;

export interface GlobalReferenceState {
  currencies: GlobalCurrency[];
  loadingCurrencies: boolean;
  currenciesError: string | null;
}

export const useGlobalReferenceStore = defineStore('globalReference', {
  state: (): GlobalReferenceState => ({
    currencies: [],
    loadingCurrencies: false,
    currenciesError: null,
  }),

  getters: {
    currencyById: (state) => (id: number) =>
      state.currencies.find((c) => c.id === id) ?? null,
    currencyByCode: (state) => (code: string) => {
      const normalized = code.trim().toUpperCase();
      return state.currencies.find((c) => c.code === normalized) ?? null;
    },
  },

  actions: {
    async ensureCurrenciesLoaded(): Promise<GlobalCurrency[]> {
      if (this.currencies.length > 0) {
        return this.currencies;
      }
      return this.loadCurrencies();
    },

    async loadCurrencies(force = false): Promise<GlobalCurrency[]> {
      if (!force && this.currencies.length > 0) {
        return this.currencies;
      }

      if (currenciesLoadPromise) {
        return currenciesLoadPromise;
      }

      this.loadingCurrencies = true;
      this.currenciesError = null;

      currenciesLoadPromise = (async () => {
        try {
          const { data, error } = await supabase
            .from('global_currencies')
            .select('*')
            .order('code', { ascending: true });

          if (error) {
            throw error;
          }

          this.currencies = (data as GlobalCurrency[] | null) ?? [];
          return this.currencies;
        } catch (err) {
          this.currenciesError =
            err instanceof Error ? err.message : 'Failed to load currencies.';
          throw err;
        } finally {
          this.loadingCurrencies = false;
          currenciesLoadPromise = null;
        }
      })();

      return currenciesLoadPromise;
    },
  },
});
