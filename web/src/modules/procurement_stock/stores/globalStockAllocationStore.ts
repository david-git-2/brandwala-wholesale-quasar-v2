import { defineStore } from 'pinia'
import {
  globalStockAllocationRepository,
  type AllocatableStock,
  type GlobalStockAllocation,
} from '../repositories/globalStockAllocationRepository'

export const useGlobalStockAllocationStore = defineStore('global_stock_allocation', {
  state: () => ({
    // Paginated list of allocatable pools (for parent view)
    allocatableStocks: [] as AllocatableStock[],
    loadingAllocatable: false,
    allocatablePage: 1,
    allocatablePageSize: 20,
    allocatableTotal: 0,
    allocatableTotalPages: 0,
    allocatableSearch: '',
    allocatableShipmentFilter: null as number | null,
    allocatableStockTypeFilter: null as number | null,

    // Active allocations list
    allocations: [] as GlobalStockAllocation[],
    loadingAllocations: false,
    allocationPage: 1,
    allocationPageSize: 20,
    allocationTotal: 0,
    allocationTotalPages: 0,
    allocationSearch: '',

    error: null as string | null,
  }),

  actions: {
    async fetchAllocatableStocks(
      tenantId: number,
      options?: {
        page?: number
        pageSize?: number
        search?: string | null
        shipmentId?: number | null
        stockTypeId?: number | null
      },
    ) {
      this.loadingAllocatable = true
      this.error = null
      try {
        const page = options?.page ?? this.allocatablePage
        const pageSize = options?.pageSize ?? this.allocatablePageSize
        const search = options?.search !== undefined ? options.search : this.allocatableSearch
        const shipmentId = options?.shipmentId !== undefined ? options.shipmentId : this.allocatableShipmentFilter
        const stockTypeId = options?.stockTypeId !== undefined ? options.stockTypeId : this.allocatableStockTypeFilter

        const result = await globalStockAllocationRepository.listAllocatableStockPaginated(
          tenantId,
          page,
          pageSize,
          search || null,
          shipmentId || null,
          stockTypeId || null,
        )

        this.allocatableStocks = result.data
        this.allocatablePage = result.meta.page
        this.allocatablePageSize = result.meta.pageSize
        this.allocatableTotal = result.meta.total
        this.allocatableTotalPages = result.meta.totalPages
        this.allocatableSearch = search || ''
        this.allocatableShipmentFilter = shipmentId
        this.allocatableStockTypeFilter = stockTypeId
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load allocatable stock'
      } finally {
        this.loadingAllocatable = false
      }
    },

    async fetchAllocations(
      tenantId: number,
      options?: {
        page?: number
        pageSize?: number
        search?: string | null
      },
    ) {
      this.loadingAllocations = true
      this.error = null
      try {
        const page = options?.page ?? this.allocationPage
        const pageSize = options?.pageSize ?? this.allocationPageSize
        const search = options?.search !== undefined ? options.search : this.allocationSearch

        const result = await globalStockAllocationRepository.listPaginated(
          tenantId,
          page,
          pageSize,
          search || null,
        )

        this.allocations = result.data
        this.allocationPage = result.meta.page
        this.allocationPageSize = result.meta.pageSize
        this.allocationTotal = result.meta.total
        this.allocationTotalPages = result.meta.totalPages
        this.allocationSearch = search || ''
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load active allocations'
      } finally {
        this.loadingAllocations = false
      }
    },

    async allocateStock(
      parentTenantId: number,
      childTenantId: number,
      stockId: number,
      quantity: number,
    ) {
      this.error = null
      try {
        await globalStockAllocationRepository.upsertGlobalStockAllocation(
          parentTenantId,
          childTenantId,
          stockId,
          quantity,
        )
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to allocate stock'
        throw err
      }
    },

    async deleteAllocation(allocationId: number) {
      this.error = null
      try {
        await globalStockAllocationRepository.deleteGlobalStockAllocation(allocationId)
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete allocation'
        throw err
      }
    },
  },
})
