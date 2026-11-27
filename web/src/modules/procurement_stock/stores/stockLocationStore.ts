import { defineStore } from 'pinia';
import { stockLocationRepository } from '../repositories/stockLocationRepository';
import type { StockLocation, UpsertStockLocationPayload } from '../types/stockLocation';

const sortLocations = (rows: StockLocation[]) =>
  [...rows].sort((a, b) => {
    if (a.sort_order !== b.sort_order) return a.sort_order - b.sort_order;
    return a.code.localeCompare(b.code);
  });

export const useStockLocationStore = defineStore('stock_location', {
  state: () => ({
    items: [] as StockLocation[],
    loading: false,
    saving: false,
    error: null as string | null,
  }),

  actions: {
    async fetchLocations(tenantId: number, includeInactive = true) {
      this.loading = true;
      this.error = null;
      try {
        const data = await stockLocationRepository.listStockLocations(
          tenantId,
          includeInactive,
        );
        this.items = sortLocations(data);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load locations';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async syncLocations(tenantId: number, includeInactive = true) {
      const data = await stockLocationRepository.listStockLocations(
        tenantId,
        includeInactive,
      );
      this.items = sortLocations(data);
    },

    async upsertLocation(tenantId: number, payload: UpsertStockLocationPayload) {
      this.saving = true;
      this.error = null;
      try {
        const row = await stockLocationRepository.upsertStockLocation(tenantId, payload);
        // Server may promote another default when deactivating / unsetting default
        await this.syncLocations(tenantId, true);
        return row;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to save location';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async setDefault(id: number) {
      this.saving = true;
      this.error = null;
      try {
        const row = await stockLocationRepository.setDefaultStockLocation(id);
        this.items = sortLocations(
          this.items.map((item) =>
            item.id === row.id ? row : { ...item, is_default: false },
          ),
        );
        return row;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to set default location';
        throw err;
      } finally {
        this.saving = false;
      }
    },

    async deleteLocation(tenantId: number, id: number) {
      this.saving = true;
      this.error = null;
      try {
        await stockLocationRepository.deleteStockLocation(id);
        await this.syncLocations(tenantId, true);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete location';
        throw err;
      } finally {
        this.saving = false;
      }
    },
  },
});
