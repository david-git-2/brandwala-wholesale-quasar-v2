import { defineStore } from 'pinia';
import { thriftRepository } from '../repositories/thriftRepository';

export const useThriftStore = defineStore('thrift', {
  state: () => ({}),

  actions: {
    async createCategory(tenantId: number, name: string, description: string, userEmail: string) {
      return thriftRepository.createCategory({
        tenant_id: tenantId,
        name,
        description,
        inserted_by: userEmail,
      });
    },

    async updateCategory(id: number, name: string, description: string) {
      return thriftRepository.updateCategory(id, { name, description });
    },

    async deleteCategory(id: number) {
      await thriftRepository.deleteCategory(id);
    },

    async createType(
      tenantId: number,
      name: string,
      description: string,
      userEmail: string,
      icon?: string | null,
    ) {
      return thriftRepository.createType({
        tenant_id: tenantId,
        name,
        description,
        icon: icon?.trim() || null,
        inserted_by: userEmail,
      });
    },

    async updateType(id: number, name: string, description: string, icon?: string | null) {
      return thriftRepository.updateType(id, {
        name,
        description,
        icon: icon?.trim() || null,
      });
    },

    async deleteType(id: number) {
      await thriftRepository.deleteType(id);
    },

    async createShelf(
      tenantId: number,
      name: string,
      locationBay: string,
      shelfCode: string,
      userEmail: string,
    ) {
      return thriftRepository.createShelf({
        tenant_id: tenantId,
        name,
        location_bay: locationBay || null,
        shelf_code: shelfCode,
        inserted_by: userEmail,
      });
    },

    async updateShelf(id: number, name: string, locationBay: string, shelfCode: string) {
      return thriftRepository.updateShelf(id, {
        name,
        location_bay: locationBay || null,
        shelf_code: shelfCode,
      });
    },

    async deleteShelf(id: number) {
      await thriftRepository.deleteShelf(id);
    },
  },
});
