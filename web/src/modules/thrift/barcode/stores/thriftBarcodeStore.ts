import { defineStore } from 'pinia';

export const useThriftBarcodeStore = defineStore('thriftBarcode', {
  state: () => ({
    page: 1,
    pageSize: 50,
    search: '',
    isPrintedFilter: null as number | null,
    statusFilter: null as string | null,
  }),

  actions: {
    setPage(page: number) {
      this.page = page;
    },
    setFilters(filters: { search?: string; isPrinted?: number | null; status?: string | null }) {
      if (filters.search !== undefined) this.search = filters.search;
      if (filters.isPrinted !== undefined) this.isPrintedFilter = filters.isPrinted;
      if (filters.status !== undefined) this.statusFilter = filters.status;
    },
    resetFilters() {
      this.page = 1;
      this.search = '';
      this.isPrintedFilter = null;
      this.statusFilter = null;
    },
  },
});
