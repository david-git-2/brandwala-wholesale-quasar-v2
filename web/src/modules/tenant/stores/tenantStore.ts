import { defineStore } from 'pinia'

import { tenantService } from '../services/tenantService'
import type {
  Tenant,
  TenantCreateInput,
  TenantDeleteInput,
  TenantStoreState,
  TenantUpdateInput,
  TenantModule,
  TenantModuleCreateInput,
  TenantModuleUpdateInput,
  TenantModuleDeleteInput,
} from '../types'

export const useTenantStore = defineStore('tenant', {
  state: (): TenantStoreState & {
    modules: TenantModule[]
    modulesLoading: boolean
    modulesError: string | null
  } => ({
    items: [],
    loading: false,
    error: null,

    modules: [],
    modulesLoading: false,
    modulesError: null,
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
console.log(result)
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



    /* ---------------- TENANT MODULES ---------------- */

    async fetchTenantModules(tenantId?: number) {
      this.modulesLoading = true
      this.modulesError = null

      try {
        const result = await tenantService.listTenantModules(tenantId)

        if (!result.success) {
          this.modulesError = result.error ?? 'Failed to load modules.'
          return result
        }

        this.modules = result.data ?? []
        return result
      } finally {
        this.modulesLoading = false
      }
    },


    async fetchTenantsByMembership(payload?: {
  tenantId?: number | null
  email?: string | null
  role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | 'customer' | null
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
  role?: 'superadmin' | 'admin' | 'staff' | 'viewer' | 'customer' | null
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


    async createTenantModule(payload: TenantModuleCreateInput) {
      this.modulesLoading = true
      this.modulesError = null

      try {
        const result = await tenantService.createTenantModule(payload)

        if (!result.success) {
          this.modulesError = result.error ?? 'Failed to create module.'
          return result
        }

        this.modules.push(result.data!)
        return result
      } finally {
        this.modulesLoading = false
      }
    },

    async updateTenantModule(payload: TenantModuleUpdateInput) {
      this.modulesLoading = true
      this.modulesError = null

      try {
        const result = await tenantService.updateTenantModule(payload)

        if (!result.success) {
          this.modulesError = result.error ?? 'Failed to update module.'
          return result
        }

        const updated = result.data!
        const index = this.modules.findIndex((m) => m.id === updated.id)

        if (index >= 0) {
          this.modules.splice(index, 1, updated)
        }

        return result
      } finally {
        this.modulesLoading = false
      }
    },

    async deleteTenantModule(payload: TenantModuleDeleteInput) {
      this.modulesLoading = true
      this.modulesError = null

      try {
        const result = await tenantService.deleteTenantModule(payload)

        if (!result.success) {
          this.modulesError = result.error ?? 'Failed to delete module.'
          return result
        }

        this.modules = this.modules.filter((m) => m.id !== payload.id)
        return result
      } finally {
        this.modulesLoading = false
      }
    },
  },
})
