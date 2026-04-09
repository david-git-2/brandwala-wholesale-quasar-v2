import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { productBasedCostingService } from '../services/productBasedCostingService'
import type {
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileDeleteInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingStoreState,
} from '../types'

export const useProductBasedCostingStore = defineStore('productBasedCosting', {
  state: (): ProductBasedCostingStoreState => ({
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchProductBasedCostingFiles() {
      this.loading = true
      this.error = null

      try {
        const result = await productBasedCostingService.listProductBasedCostingFiles()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load product based costing files.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
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
        }

        showSuccessNotification('Product based costing file updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteProductBasedCostingFile(payload: ProductBasedCostingFileDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productBasedCostingService.deleteProductBasedCostingFile(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete product based costing file.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        showSuccessNotification('Product based costing file deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
