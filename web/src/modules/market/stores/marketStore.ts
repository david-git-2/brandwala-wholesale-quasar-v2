import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
import { marketService } from '../services/marketService'
import type {
  Market,
  MarketCreateInput,
  MarketDeleteInput,
  MarketStoreState,
  MarketUpdateInput,
} from '../types'

export const useMarketStore = defineStore('market', {
  state: (): MarketStoreState => ({
    items: [],
    loading: true,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchMarkets() {
      this.loading = true
      this.error = null

      try {
        const result = await marketService.listMarkets()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load markets.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createMarket(market: MarketCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await marketService.createMarket(market)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create market.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items.push(result.data!)
        showSuccessNotification('Market created successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async updateMarket(market: MarketUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await marketService.updateMarket(market)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update market.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedMarket = result.data!
        const index = this.items.findIndex((item) => item.id === updatedMarket.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedMarket)
        }

        showSuccessNotification('Market updated successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async deleteMarket(market: MarketDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await marketService.deleteMarket(market)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete market.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item: Market) => item.id !== market.id)
        showSuccessNotification('Market deleted successfully.')
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
