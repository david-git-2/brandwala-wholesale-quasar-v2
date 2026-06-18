import { defineStore } from 'pinia';
import { thriftBarcodeRepository } from '../repositories/thriftBarcodeRepository';
import type { ThriftBarcode } from '../types';

export const useThriftBarcodeStore = defineStore('thriftBarcode', {
  state: () => ({
    barcodes: [] as ThriftBarcode[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async fetchBarcodes(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.barcodes = await thriftBarcodeRepository.fetchBarcodes(tenantId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load barcodes';
      } finally {
        this.loading = false;
      }
    },

    async generateBarcodes(params: {
      tenantId: number;
      quantity: number;
      insertedBy: string;
    }) {
      this.loading = true;
      this.error = null;
      try {
        await thriftBarcodeRepository.generateBarcodes(params);
        // Reload list to get updated sequences
        this.barcodes = await thriftBarcodeRepository.fetchBarcodes(params.tenantId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to generate barcodes';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async markBarcodesPrinted(ids: number[]) {
      this.loading = true;
      this.error = null;
      try {
        await thriftBarcodeRepository.markBarcodesPrinted(ids);
        // Update local status for the marked items
        this.barcodes = this.barcodes.map((b) =>
          ids.includes(b.id) ? { ...b, is_printed: 1 } : b
        );
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to mark barcodes as printed';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
