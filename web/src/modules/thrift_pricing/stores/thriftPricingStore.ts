import { defineStore } from 'pinia';
import { thriftPricingRepository } from '../repositories/thriftPricingRepository';
import type { ThriftPricing } from '../types';

export const useThriftPricingStore = defineStore('thrift_pricing', {
  state: () => ({
    pricings: [] as Array<ThriftPricing & { thrift_stocks: { name: string; sku: string } }>,
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadPricings(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.pricings = await thriftPricingRepository.fetchPricings(tenantId) as any;
      } catch (err: any) {
        this.error = err.message || 'Failed to load pricing';
      } finally {
        this.loading = false;
      }
    },

    async updatePricing(id: number, cost: number, target: number, listed: number) {
      try {
        await thriftPricingRepository.updatePricing(id, cost, target, listed);
        const idx = this.pricings.findIndex(p => p.id === id);
        if (idx !== -1) {
          this.pricings[idx]!.cost_of_goods_sold = cost;
          this.pricings[idx]!.target_price = target;
          this.pricings[idx]!.listed_price = listed;
        }
      } catch (err: any) {
        this.error = err.message || 'Failed to update pricing';
        throw err;
      }
    },
  },
});
