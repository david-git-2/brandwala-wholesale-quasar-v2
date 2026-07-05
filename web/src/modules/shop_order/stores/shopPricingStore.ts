import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { shopPricingService } from '../services/shopPricingService'
import type {
  ShopProductListing,
  CandidateAllocation,
  UpsertListingPayload,
} from '../types'

interface Currency {
  id: number
  code: string
  name: string
}

export interface ShopPricingState {
  listings: ShopProductListing[]
  loadingListings: boolean
  candidates: CandidateAllocation[]
  loadingCandidates: boolean
  currencies: Currency[]
  loadingCurrencies: boolean
  saving: boolean
  error: string | null
}

export const useShopPricingStore = defineStore('shopPricing', {
  state: (): ShopPricingState => ({
    listings: [],
    loadingListings: false,
    candidates: [],
    loadingCandidates: false,
    currencies: [],
    loadingCurrencies: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchListings(shopId: number) {
      this.loadingListings = true
      this.error = null
      try {
        const res = await shopPricingService.listListings(shopId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        this.listings = res.data ?? []
        return res
      } finally {
        this.loadingListings = false
      }
    },

    async fetchCandidates(tenantId: number, shopId: number) {
      this.loadingCandidates = true
      this.error = null
      try {
        const res = await shopPricingService.listCandidateAllocations(tenantId, shopId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        this.candidates = res.data ?? []
        return res
      } finally {
        this.loadingCandidates = false
      }
    },

    async saveListing(payload: UpsertListingPayload) {
      this.saving = true
      this.error = null
      try {
        const res = await shopPricingService.upsertListing(payload)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        
        // Refresh listings list
        await this.fetchListings(payload.shop_id)
        
        showSuccessNotification('Shop product listing saved successfully.')
        return res
      } finally {
        this.saving = false
      }
    },

    async fetchCurrencies() {
      if (this.currencies.length > 0) return
      this.loadingCurrencies = true
      try {
        const res = await shopPricingService.listCurrencies()
        if (!res.success) {
          this.error = res.error
          return res
        }
        this.currencies = res.data ?? []
        return res
      } finally {
        this.loadingCurrencies = false
      }
    },
  },
})
