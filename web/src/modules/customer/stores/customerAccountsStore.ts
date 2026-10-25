import { defineStore } from 'pinia';
import { customerRepository } from '../repositories/customerRepository';
import type { CustomerAccount } from '../types/customer';

const loadPromises = new Map<number, Promise<CustomerAccount[]>>();

export const useCustomerAccountsStore = defineStore('customerAccounts', {
  state: () => ({
    byTenantId: {} as Record<number, CustomerAccount[]>,
    loadedTenantIds: {} as Record<number, true>,
    loadingTenantId: null as number | null,
    error: null as string | null,
  }),

  actions: {
    async ensureLoaded(tenantId: number): Promise<CustomerAccount[]> {
      if (this.loadedTenantIds[tenantId]) {
        return this.byTenantId[tenantId] ?? [];
      }

      const inFlight = loadPromises.get(tenantId);
      if (inFlight) {
        return inFlight;
      }

      this.loadingTenantId = tenantId;
      this.error = null;

      const promise = (async () => {
        try {
          const rows = await customerRepository.listCustomers(tenantId);
          this.byTenantId[tenantId] = rows;
          this.loadedTenantIds[tenantId] = true;
          return rows;
        } catch (err) {
          this.error = err instanceof Error ? err.message : 'Failed to load customers.';
          throw err;
        } finally {
          this.loadingTenantId = null;
          loadPromises.delete(tenantId);
        }
      })();

      loadPromises.set(tenantId, promise);
      return promise;
    },
  },
});
