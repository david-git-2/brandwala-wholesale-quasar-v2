import { defineStore } from 'pinia';
import { thriftShelfRepository } from '../repositories/thriftShelfRepository';
import type { ThriftShelf } from '../types';

export const useThriftShelfStore = defineStore('thrift_shelf', {
  state: () => ({
    shelves: [] as ThriftShelf[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadShelves(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.shelves = await thriftShelfRepository.fetchShelves(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load shelves';
      } finally {
        this.loading = false;
      }
    },

    async createShelf(tenantId: number, name: string, locationBay: string, shelfCode: string, userEmail: string) {
      try {
        const shlf = await thriftShelfRepository.createShelf({
          tenant_id: tenantId,
          name,
          location_bay: locationBay,
          shelf_code: shelfCode,
          inserted_by: userEmail,
        });
        this.shelves.push(shlf);
        return shlf;
      } catch (err: any) {
        this.error = err.message || 'Failed to create shelf';
        throw err;
      }
    },
  },
});
