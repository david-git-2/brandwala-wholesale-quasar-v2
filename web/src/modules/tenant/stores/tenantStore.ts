import { defineStore } from 'pinia'

import { tenantService } from '../services/tenantService'
import type { Tenant, TenantCreateInput, TenantDeleteInput, TenantStoreState, TenantUpdateInput } from '../types'

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
    async createTenant(tenant: TenantCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.createTenant(tenant)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create tenant.'
          return result
        }

        this.items.push(result.data!)
        return result
      } finally {
        this.loading = false
      }
    },
    async updateTenant(tenant: TenantUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.updateTenant(tenant)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update tenant.'
          return result
        }

        const updatedTenant = result.data!
        const index = this.items.findIndex((item) => item.id === updatedTenant.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedTenant)
        }

        return result
      } finally {
        this.loading = false
      }
    },
    async deleteTenant(tenant: TenantDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.deleteTenant(tenant)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete tenant.'
          return result
        }

        this.items = this.items.filter((item: Tenant) => item.id !== tenant.id)
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
