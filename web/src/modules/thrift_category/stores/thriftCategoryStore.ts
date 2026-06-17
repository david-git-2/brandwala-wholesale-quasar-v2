import { defineStore } from 'pinia';
import { thriftCategoryRepository } from '../repositories/thriftCategoryRepository';
import type { ThriftCategory } from '../types';

export const useThriftCategoryStore = defineStore('thrift_category', {
  state: () => ({
    categories: [] as ThriftCategory[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadCategories(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.categories = await thriftCategoryRepository.fetchCategories(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load categories';
      } finally {
        this.loading = false;
      }
    },

    async createCategory(tenantId: number, name: string, description: string, userEmail: string) {
      try {
        const cat = await thriftCategoryRepository.createCategory({
          tenant_id: tenantId,
          name,
          description,
          inserted_by: userEmail,
        });
        this.categories.push(cat);
        return cat;
      } catch (err: any) {
        this.error = err.message || 'Failed to create category';
        throw err;
      }
    },
  },
});
