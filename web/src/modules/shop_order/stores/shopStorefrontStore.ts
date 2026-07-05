import { defineStore } from 'pinia'
import { handleApiFailure } from 'src/utils/appFeedback'
import { shopOrderService } from '../services/shopOrderService'

export const useShopStorefrontStore = defineStore('shopStorefront', {
  state: () => ({
    shopDetails: null as any,
    catalogItems: [] as any[],
    permissions: null as any,
    loading: false,
    error: null as string | null,
    totalItems: 0,
    pageSize: 20,
    currentPage: 1,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchCatalog(
      shopSlug: string,
      opts: {
        search?: string | null
        category?: string | null
        brand?: string | null
        limit?: number
        offset?: number
        append?: boolean
      } = {},
    ) {
      this.loading = true
      this.error = null

      try {
        const result = await shopOrderService.browseShopCatalog(shopSlug, {
          search: opts.search,
          category: opts.category,
          brand: opts.brand,
          limit: opts.limit ?? this.pageSize,
          offset: opts.offset ?? 0,
        })

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        const data = result.data?.data ?? []
        const meta = result.data?.meta ?? {}

        this.shopDetails = meta.shop ?? null
        this.permissions = meta.permissions ?? null
        this.totalItems = meta.total ?? 0
        this.pageSize = meta.page_size ?? this.pageSize
        this.currentPage = meta.page ?? 1

        if (opts.append) {
          // Prevent duplicates by checking product_id or global_stock_allocation_id
          const existingIds = new Set(
            this.catalogItems.map((item) => item.product_id + '-' + (item.global_stock_allocation_id ?? ''))
          )
          const newItems = data.filter(
            (item: any) => !existingIds.has(item.product_id + '-' + (item.global_stock_allocation_id ?? ''))
          )
          this.catalogItems = [...this.catalogItems, ...newItems]
        } else {
          this.catalogItems = data
        }

        return result
      } catch (err) {
        this.error = err instanceof Error ? err.message : 'Unknown error occurred.'
        return { success: false, error: this.error }
      } finally {
        this.loading = false
      }
    },
  },
})
