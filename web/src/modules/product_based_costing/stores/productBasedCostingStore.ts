import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { productBasedCostingService } from '../services/productBasedCostingService'
import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileListInput,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemUpdateInput,
  ProductBasedCostingStoreState,
} from '../types'

export const useProductBasedCostingStore = defineStore('productBasedCosting', {
  state: (): ProductBasedCostingStoreState => ({
    items: [],
    item: null,

    costingItems: [],
    costingItem: null,
    total: 0,
    page: 1,
    page_size: 20,
    total_pages: 1,

    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    clearSelectedItem() {
      this.item = null
    },

    clearSelectedCostingItem() {
      this.costingItem = null
    },

    setSelectedItem(item: ProductBasedCostingFile | null) {
      this.item = item
    },

    setSelectedCostingItem(item: ProductBasedCostingItem | null) {
      this.costingItem = item
    },

    async fetchProductBasedCostingFiles(payload: ProductBasedCostingFileListInput = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await productBasedCostingService.listProductBasedCostingFiles(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load product based costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data?.data ?? []
        this.total = result.data?.meta.total ?? 0
        this.page = result.data?.meta.page ?? (payload.page ?? 1)
        this.page_size = result.data?.meta.page_size ?? (payload.page_size ?? 20)
        this.total_pages = result.data?.meta.total_pages ?? 1
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchProductBasedCostingFileById(id: number) {
      this.loading = true
      this.error = null

      try {
        const result = await productBasedCostingService.getProductBasedCostingFileById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load product based costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        this.item = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async createProductBasedCostingFile(payload: ProductBasedCostingFileCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.createProductBasedCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create product based costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.push(result.data)
          this.item = result.data
        }

        showSuccessNotification('Product based costing file created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateProductBasedCostingFile(payload: ProductBasedCostingFileUpdateInput) {
      this.saving = true
      this.error = null

      try {
        console.log('Updating product based costing file with payload:', payload)
        const result = await productBasedCostingService.updateProductBasedCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update product based costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }

          this.item = result.data
        }

        showSuccessNotification('Product based costing file updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteProductBasedCostingFile(payload: number) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.deleteProductBasedCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete product based costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload)

        if (this.item?.id === payload) {
          this.item = null
        }

        this.costingItems = []
        this.costingItem = null

        showSuccessNotification('Product based costing file deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchProductBasedCostingItems(productBasedCostingFileId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await productBasedCostingService.listProductBasedCostingItems(
          productBasedCostingFileId,
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to load product based costing items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingItems = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchProductBasedCostingItemById(id: number) {
      this.loading = true
      this.error = null

      try {
        const result = await productBasedCostingService.getProductBasedCostingItemById(id)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load product based costing item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingItem = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async createProductBasedCostingItem(payload: ProductBasedCostingItemCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.createProductBasedCostingItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create product based costing item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.costingItems.push(result.data)
          this.costingItem = result.data
        }

        showSuccessNotification('Product based costing item created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateProductBasedCostingItem(payload: ProductBasedCostingItemUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.updateProductBasedCostingItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update product based costing item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.costingItems.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.costingItems.splice(index, 1, result.data)
          }

          this.costingItem = result.data
        }

        showSuccessNotification('Product based costing item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteProductBasedCostingItem(payload: number) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.deleteProductBasedCostingItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete product based costing item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.costingItems = this.costingItems.filter((item) => item.id !== payload)

        if (this.costingItem?.id === payload) {
          this.costingItem = null
        }

        showSuccessNotification('Product based costing item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
