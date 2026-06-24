import { defineStore } from 'pinia'
import { globalStockAllocationRepository, type GlobalStockAllocation } from '../repositories/globalStockAllocationRepository'

export const useTenantStockStore = defineStore('tenant_stock_allocation', {
  state: () => ({
    rows: [] as GlobalStockAllocation[],
    loading: false,
    error: null as string | null,
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 0,
    search: '',
    childTenantFilter: null as number | null,
    stockTypeFilter: null as number | null,
  }),

  actions: {
    async fetchAllocations(
      tenantId: number,
      options?: {
        page?: number
        pageSize?: number
        search?: string | null
        childTenantId?: number | null
        stockTypeId?: number | null
      },
    ) {
      this.loading = true
      this.error = null
      try {
        const page = options?.page ?? this.page
        const pageSize = options?.pageSize ?? this.pageSize
        const search = options?.search !== undefined ? options.search : this.search
        const childTenantId = options?.childTenantId !== undefined ? options.childTenantId : this.childTenantFilter
        const stockTypeId = options?.stockTypeId !== undefined ? options.stockTypeId : this.stockTypeFilter

        const result = await globalStockAllocationRepository.listPaginated(
          tenantId,
          page,
          pageSize,
          search || undefined,
          childTenantId,
          stockTypeId,
        )

        this.rows = result.data
        this.page = result.meta.page
        this.pageSize = result.meta.pageSize
        this.total = result.meta.total
        this.totalPages = result.meta.totalPages
        this.search = search || ''
        this.childTenantFilter = childTenantId
        this.stockTypeFilter = stockTypeId
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load allocations'
      } finally {
        this.loading = false
      }
    },
  },
})
