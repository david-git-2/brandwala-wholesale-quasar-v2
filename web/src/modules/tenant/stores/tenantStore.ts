import { defineStore } from 'pinia'

import { tenantService } from '../services/tenantService'
import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantStoreState,
  TenantUpdateInput,
} from '../types'

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

    /* ---------------- TENANTS ---------------- */

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
    async fetchAdminTenantsByEmail() {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.listAdminTenantsByEmail()

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
    async fetchTenantsByMembership(payload?: {
      tenantId?: number | null
      email?: string | null
      role?: 'superadmin' | 'admin' | 'staff' | null
    }) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.listTenantsByMembership(payload)

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

    async fetchTenantDetailsByMembership(payload: {
      tenantId: number
      email?: string | null
      role?: 'superadmin' | 'admin' | 'staff' | null
    }) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.getTenantDetailsByMembership(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load tenant details.'
          return result
        }

        const tenant = result.data

        if (tenant) {
          const index = this.items.findIndex((item) => item.id === tenant.id)

          if (index >= 0) {
            this.items.splice(index, 1, tenant)
          } else {
            this.items.push(tenant)
          }
        }

        return result
      } finally {
        this.loading = false
      }
    },
  },
})
