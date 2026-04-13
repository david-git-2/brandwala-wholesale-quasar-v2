import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { storeService } from '../services/storeService'
import type {
  StoreAccessCreateInput,
  StoreAccessDeleteInput,
  StoreAccessUpdateInput,
  StoreCreateInput,
  StoreDeleteInput,
  StoreProductsQueryInput,
  StoreStoreState,
  StoreUpdateInput,
} from '../types'

export const useStoreStore = defineStore('store', {
  state: (): StoreStoreState => ({
    items: [],
    accessItems: [],
    productItems: [],
    loading: false,
    saving: false,
    error: null,
    productsTotal: 0,
    productsOffset: 0,
    productsPage: 1,
    productsPageSize: 20,
    productsCanSeePrice: false,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchStoresAdmin(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await storeService.getStoresAdmin(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load stores.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchStoresForCustomer() {
      this.loading = true
      this.error = null

      try {
        const result = await storeService.getStoresForCustomer()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load stores.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createStore(payload: StoreCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.createStore(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create store.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }

        showSuccessNotification('Store created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateStore(payload: StoreUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.updateStore(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update store.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Store updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteStore(payload: StoreDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.deleteStore(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete store.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)

        showSuccessNotification('Store deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchStoreAccessAdmin(storeId?: number | null) {
      this.loading = true
      this.error = null

      try {
        const result = await storeService.getStoreAccessAdmin(storeId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load store access.'
          handleApiFailure(result, this.error)
          return result
        }

        this.accessItems = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createStoreAccess(payload: StoreAccessCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.createStoreAccess(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create store access.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.accessItems.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.accessItems.splice(index, 1, result.data)
          } else {
            this.accessItems.push(result.data)
          }
        }

        showSuccessNotification('Store access created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateStoreAccess(payload: StoreAccessUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.updateStoreAccess(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update store access.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.accessItems.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.accessItems.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Store access updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteStoreAccess(payload: StoreAccessDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await storeService.deleteStoreAccess(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete store access.'
          handleApiFailure(result, this.error)
          return result
        }

        this.accessItems = this.accessItems.filter((item) => item.id !== payload.id)

        showSuccessNotification('Store access deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async checkStoreAccess(storeId: number) {
      const result = await storeService.checkStoreAccess(storeId)

      if (!result.success) {
        this.error = result.error ?? 'Failed to check store access.'
        handleApiFailure(result, this.error)
      }

      return result
    },

    async checkStorePriceAccess(storeId: number) {
      const result = await storeService.checkStorePriceAccess(storeId)

      if (!result.success) {
        this.error = result.error ?? 'Failed to check store price access.'
        handleApiFailure(result, this.error)
      }

      return result
    },

    async fetchStoreProducts(payload: StoreProductsQueryInput) {
      this.loading = true
      this.error = null

      try {
        const safeLimit = Math.max(1, Math.floor(payload.limit ?? this.productsPageSize))
        const safeOffset = Math.max(0, Math.floor(payload.offset ?? 0))

        const result = await storeService.listStoreProducts({
          ...payload,
          limit: safeLimit,
          offset: safeOffset,
        })

        if (!result.success) {
          this.error = result.error ?? 'Failed to load store products.'
          handleApiFailure(result, this.error)
          return result
        }

        const items = result.data?.data ?? []
        const meta = result.data?.meta

        this.productItems = items
        this.productsTotal = meta?.total ?? 0
        this.productsOffset = meta?.offset ?? safeOffset
        this.productsPageSize = meta?.limit ?? safeLimit
        this.productsPage = meta?.current_page ?? Math.floor(safeOffset / safeLimit) + 1
        this.productsCanSeePrice = meta?.can_see_price ?? false

        return result
      } finally {
        this.loading = false
      }
    },
  },
})
