import { defineStore } from 'pinia'

import { tenantService } from '../services/tenantService'
import type { TenantStoreState } from '../types'

export const useTenantStore = defineStore('tenant', {
  state: (): TenantStoreState => ({
    items: [],
    loading: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchTenants() {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.listTenants()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load tenants.'
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
