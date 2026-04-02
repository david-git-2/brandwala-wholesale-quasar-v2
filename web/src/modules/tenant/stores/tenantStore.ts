import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
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
    loading: true,
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
          handleApiFailure(result, this.error)
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
          handleApiFailure(result, this.error)
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
          handleApiFailure(result, this.error)
          return result
        }

        this.items.push(result.data!)
        showSuccessNotification('Tenant created successfully.')
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
          handleApiFailure(result, this.error)
          return result
        }

        const updatedTenant = result.data!
        const index = this.items.findIndex((item) => item.id === updatedTenant.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedTenant)
        }

        showSuccessNotification('Tenant updated successfully.')
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
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item: Tenant) => item.id !== tenant.id)
        showSuccessNotification('Tenant deleted successfully.')
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
          handleApiFailure(result, this.error)
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
          handleApiFailure(result, this.error)
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
