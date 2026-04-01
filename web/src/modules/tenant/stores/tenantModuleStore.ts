import { defineStore } from 'pinia'

import { tenantService } from '../services/tenantService'
import type {
  TenantModule,
  TenantModuleCreateInput,
  TenantModuleDeleteInput,
  TenantModuleUpdateInput,
} from '../types'

export const useTenantModuleStore = defineStore('tenantModule', {
  state: () => ({
    items: [] as TenantModule[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchTenantModules(tenantId?: number) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.listTenantModules(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load modules.'
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createTenantModule(payload: TenantModuleCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.createTenantModule(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create module.'
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async updateTenantModule(payload: TenantModuleUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.updateTenantModule(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update module.'
          return result
        }

        const updated = result.data

        if (updated) {
          const index = this.items.findIndex((item) => item.id === updated.id)

          if (index >= 0) {
            this.items.splice(index, 1, updated)
          }
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async deleteTenantModule(payload: TenantModuleDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await tenantService.deleteTenantModule(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete module.'
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
