import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { vendorService } from '../services/vendorService'
import type {
  VendorCreateInput,
  VendorDeleteInput,
  VendorStoreState,
  VendorUpdateInput,
} from '../types'

export const useVendorStore = defineStore('vendor', {
  state: (): VendorStoreState => ({
    items: [],
    markets: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchVendors() {
      this.loading = true
      this.error = null

      try {
        const result = await vendorService.listVendors()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load vendors.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchMarkets() {
      const result = await vendorService.listVendorMarkets()

      if (!result.success) {
        this.error = result.error ?? 'Failed to load markets.'
        handleApiFailure(result, this.error)
        return result
      }

      this.markets = result.data ?? []
      return result
    },

    async checkCodeAvailability(code: string, excludeId?: number | null) {
      return vendorService.isVendorCodeAvailable(code, excludeId)
    },

    async createVendor(payload: VendorCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await vendorService.createVendor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create vendor.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }
        showSuccessNotification('Vendor created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateVendor(payload: VendorUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await vendorService.updateVendor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update vendor.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Vendor updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteVendor(payload: VendorDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await vendorService.deleteVendor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete vendor.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        showSuccessNotification('Vendor deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
