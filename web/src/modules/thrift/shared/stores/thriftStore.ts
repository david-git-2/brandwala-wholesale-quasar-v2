import { defineStore } from 'pinia';
import { thriftRepository } from '../repositories/thriftRepository';
import type { ThriftCategory } from '../../category/types';
import type { ThriftType } from '../../type/types';
import type { ThriftBox } from '../../box/types';
import type { ThriftShelf } from '../../shelf/types';

export const useThriftStore = defineStore('thrift', {
  state: () => ({
    categories: [] as ThriftCategory[],
    types: [] as ThriftType[],
    boxes: [] as ThriftBox[],
    shelves: [] as ThriftShelf[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadModuleData(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        const [cats, typs, boxes, shelves] = await Promise.all([
          thriftRepository.fetchCategories(tenantId),
          thriftRepository.fetchTypes(tenantId),
          thriftRepository.fetchBoxes(tenantId),
          thriftRepository.fetchShelves(tenantId),
        ]);

        this.categories = cats;
        this.types = typs;
        this.boxes = boxes;
        this.shelves = shelves;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load Thrift module data';
      } finally {
        this.loading = false;
      }
    },

    async createCategory(tenantId: number, name: string, description: string, userEmail: string) {
      const cat = await thriftRepository.createCategory({
        tenant_id: tenantId,
        name,
        description,
        inserted_by: userEmail,
      });
      this.categories.push(cat);
      return cat;
    },

    async updateCategory(id: number, name: string, description: string) {
      const cat = await thriftRepository.updateCategory(id, { name, description });
      const idx = this.categories.findIndex(c => c.id === id);
      if (idx !== -1) this.categories[idx] = cat;
      return cat;
    },

    async deleteCategory(id: number) {
      await thriftRepository.deleteCategory(id);
      this.categories = this.categories.filter(c => c.id !== id);
    },

    async createType(
      tenantId: number,
      name: string,
      description: string,
      userEmail: string,
      icon?: string | null,
    ) {
      const typ = await thriftRepository.createType({
        tenant_id: tenantId,
        name,
        description,
        icon: icon?.trim() || null,
        inserted_by: userEmail,
      });
      this.types.push(typ);
      return typ;
    },

    async updateType(id: number, name: string, description: string, icon?: string | null) {
      const typ = await thriftRepository.updateType(id, {
        name,
        description,
        icon: icon?.trim() || null,
      });
      const idx = this.types.findIndex(t => t.id === id);
      if (idx !== -1) this.types[idx] = typ;
      return typ;
    },

    async deleteType(id: number) {
      await thriftRepository.deleteType(id);
      this.types = this.types.filter(t => t.id !== id);
    },

    async createShelf(
      tenantId: number,
      name: string,
      locationBay: string,
      shelfCode: string,
      userEmail: string,
    ) {
      const shelf = await thriftRepository.createShelf({
        tenant_id: tenantId,
        name,
        location_bay: locationBay || null,
        shelf_code: shelfCode,
        inserted_by: userEmail,
      });
      this.shelves.push(shelf);
      return shelf;
    },

    async updateShelf(id: number, name: string, locationBay: string, shelfCode: string) {
      const shelf = await thriftRepository.updateShelf(id, {
        name,
        location_bay: locationBay || null,
        shelf_code: shelfCode,
      });
      const idx = this.shelves.findIndex(s => s.id === id);
      if (idx !== -1) this.shelves[idx] = shelf;
      return shelf;
    },

    async deleteShelf(id: number) {
      await thriftRepository.deleteShelf(id);
      this.shelves = this.shelves.filter(s => s.id !== id);
    },
  },
});
