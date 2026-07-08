import { defineStore } from 'pinia';
import { thriftBarcodeRepository } from '../repositories/thriftBarcodeRepository';
import type { ThriftBarcode, ThriftBarcodeListMeta } from '../types';

const emptyMeta = (): ThriftBarcodeListMeta => ({
  total: 0,
  page: 1,
  page_size: 50,
  total_pages: 0,
  unprinted_total: 0,
  available_total: 0,
  printable_total: 0,
  latest_current_year_barcode_id: null,
});

export const useThriftBarcodeStore = defineStore('thriftBarcode', {
  state: () => ({
    barcodes: [] as ThriftBarcode[],
    loading: false,
    error: null as string | null,
    page: 1,
    pageSize: 50,
    total: 0,
    totalPages: 0,
    meta: emptyMeta(),
    search: '',
    isPrintedFilter: null as number | null,
    statusFilter: null as string | null,
  }),

  actions: {
    async loadBarcodes(
      tenantId: number,
      options?: {
        page?: number;
        pageSize?: number;
        search?: string;
        isPrinted?: number | null;
        status?: string | null;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const page = options?.page ?? this.page;
        const pageSize = options?.pageSize ?? this.pageSize;
        const search = options?.search ?? this.search;
        const isPrinted =
          options?.isPrinted !== undefined ? options.isPrinted : this.isPrintedFilter;
        const status = options?.status !== undefined ? options.status : this.statusFilter;

        const result = await thriftBarcodeRepository.fetchBarcodesPaginated({
          tenantId,
          page,
          pageSize,
          search,
          isPrinted,
          status,
        });

        this.barcodes = result.data;
        this.page = result.meta.page;
        this.pageSize = result.meta.page_size;
        this.total = result.meta.total;
        this.totalPages = result.meta.total_pages;
        this.meta = result.meta;
        this.search = search;
        this.isPrintedFilter = isPrinted;
        this.statusFilter = status;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load barcodes';
      } finally {
        this.loading = false;
      }
    },

    async fetchPrintableForPrint(tenantId: number, quantity: number): Promise<ThriftBarcode[]> {
      const result = await thriftBarcodeRepository.fetchBarcodesPaginated({
        tenantId,
        page: 1,
        pageSize: quantity,
        isPrinted: 0,
        status: 'AVAILABLE',
      });
      return result.data;
    },

    async fetchBarcodesByIds(ids: number[]): Promise<ThriftBarcode[]> {
      return thriftBarcodeRepository.fetchBarcodesByIds(ids);
    },

    async generateBarcodes(params: { tenantId: number; quantity: number; insertedBy: string }) {
      this.loading = true;
      this.error = null;
      try {
        await thriftBarcodeRepository.generateBarcodes(params);
        await this.loadBarcodes(params.tenantId, { page: 1 });
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to generate barcodes';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async markBarcodesPrinted(ids: number[], tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        await thriftBarcodeRepository.markBarcodesPrinted(ids);
        this.barcodes = this.barcodes.map((b) =>
          ids.includes(b.id) ? { ...b, is_printed: 1 } : b,
        );
        await this.loadBarcodes(tenantId, { page: this.page });
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to mark barcodes as printed';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
