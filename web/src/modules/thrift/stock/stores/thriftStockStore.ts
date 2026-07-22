import { defineStore } from 'pinia';

export const useThriftStockStore = defineStore('thrift_stock', {
  state: () => ({
    page: 1,
    pageSize: 20,
    search: '',
    statusFilter: null as string | null,
    conditionFilter: null as string | null,
  }),

  actions: {
    setPage(page: number) {
      this.page = page;
    },

    setPageSize(pageSize: number) {
      this.pageSize = pageSize;
    },

    setSearch(search: string) {
      this.search = search;
    },

    setStatusFilter(status: string | null) {
      this.statusFilter = status;
    },

    setConditionFilter(condition: string | null) {
      this.conditionFilter = condition;
    },

    resetFilters() {
      this.search = '';
      this.statusFilter = null;
      this.conditionFilter = null;
      this.page = 1;
    },
  },
});
