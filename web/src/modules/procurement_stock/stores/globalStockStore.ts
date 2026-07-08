import { defineStore } from 'pinia';
import { globalStockRepository, type GlobalStock } from '../repositories/globalStockRepository';

export const useGlobalStockStore = defineStore('global_stock', {
  state: () => ({
    rows: [] as GlobalStock[],
    loading: false,
    error: null as string | null,
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 0,
    search: '',
    stockTypeFilter: null as number | null,
    isSellableFilter: null as boolean | null,
    shipmentStatusFilter: null as string | null,
    hideZeroStockFilter: true,
  }),

  actions: {
    async fetchStocks(
      tenantId: number,
      options?: {
        page?: number;
        pageSize?: number;
        search?: string | null;
        stockTypeId?: number | null;
        isSellable?: boolean | null;
        shipmentStatus?: string | null;
        hideZeroStock?: boolean;
      },
    ) {
      this.loading = true;
      this.error = null;
      try {
        const page = options?.page ?? this.page;
        const pageSize = options?.pageSize ?? this.pageSize;
        const search = options?.search !== undefined ? options.search : this.search;
        const stockTypeId =
          options?.stockTypeId !== undefined ? options.stockTypeId : this.stockTypeFilter;
        const isSellable =
          options?.isSellable !== undefined ? options.isSellable : this.isSellableFilter;
        const shipmentStatus =
          options?.shipmentStatus !== undefined
            ? options.shipmentStatus
            : this.shipmentStatusFilter;
        const hideZeroStock =
          options?.hideZeroStock !== undefined ? options.hideZeroStock : this.hideZeroStockFilter;

        const result = await globalStockRepository.listPaginated(
          tenantId,
          page,
          pageSize,
          search || undefined,
          stockTypeId,
          isSellable,
          shipmentStatus,
          hideZeroStock,
        );

        this.rows = result.data;
        this.page = result.meta.page;
        this.pageSize = result.meta.pageSize;
        this.total = result.meta.total;
        this.totalPages = result.meta.totalPages;
        this.search = search || '';
        this.stockTypeFilter = stockTypeId;
        this.isSellableFilter = isSellable;
        this.shipmentStatusFilter = shipmentStatus;
        this.hideZeroStockFilter = hideZeroStock;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load stock';
      } finally {
        this.loading = false;
      }
    },
  },
});
