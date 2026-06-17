import { defineStore } from 'pinia';
import { thriftTypeRepository } from '../repositories/thriftTypeRepository';
import type { ThriftType } from '../types';

export const useThriftTypeStore = defineStore('thrift_type', {
  state: () => ({
    types: [] as ThriftType[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadTypes(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.types = await thriftTypeRepository.fetchTypes(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load thrift style types';
      } finally {
        this.loading = false;
      }
    },

    async createType(tenantId: number, name: string, description: string, userEmail: string) {
      try {
        const typ = await thriftTypeRepository.createType({
          tenant_id: tenantId,
          name,
          description,
          inserted_by: userEmail,
        });
        this.types.push(typ);
        return typ;
      } catch (err: any) {
        this.error = err.message || 'Failed to create type';
        throw err;
      }
    },
  },
});
