import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
import { productService } from '../services/productService'
import type {
  ProductCreateInput,
  ProductDeleteInput,
  ProductStoreState,
  ProductUpdateInput,
} from '../types'

export const useProductStore = defineStore('product', {
  state: (): ProductStoreState => ({
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchProducts() {
      this.loading = true
      this.error = null

      try {
        const result = await productService.listProducts()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load products.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createProduct(payload: ProductCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.createProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create product.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }

        showSuccessNotification('Product created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateProduct(payload: ProductUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.updateProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update product.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Product updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteProduct(payload: ProductDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.deleteProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete product.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        showSuccessNotification('Product deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
