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

type StoredTenantWorkspace = {
  schemaVersion: 1
  availableAdminTenants: Tenant[]
  selectedTenantId: Tenant['id'] | null
  selectedTenantSlug: Tenant['slug'] | null
}

const STORAGE_KEY = 'brandwala.tenant.workspace.v1'

const readStorage = (): StoredTenantWorkspace | null => {
  if (typeof window === 'undefined') {
    return null
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY)

  if (!rawValue) {
    return null
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<StoredTenantWorkspace>

    if (
      parsed?.schemaVersion !== 1 ||
      !Array.isArray(parsed.availableAdminTenants)
    ) {
      return null
    }

    return parsed as StoredTenantWorkspace
  } catch {
    return null
  }
}

const writeStorage = (value: StoredTenantWorkspace | null) => {
  if (typeof window === 'undefined') {
    return
  }

  if (!value) {
    window.localStorage.removeItem(STORAGE_KEY)
    return
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
}

export const clearTenantWorkspaceStorage = () => {
  writeStorage(null)
}

const storedWorkspace = readStorage()

export const useTenantStore = defineStore('tenant', {
  state: (): TenantStoreState => ({
    items: [],
    availableAdminTenants: storedWorkspace?.availableAdminTenants ?? [],
    selectedTenantId: storedWorkspace?.selectedTenantId ?? null,
    selectedTenantSlug: storedWorkspace?.selectedTenantSlug ?? null,
    loading: true,
    error: null,
  }),

  getters: {
    selectedTenant(state): Tenant | null {
      const fromAvailableTenants =
        state.availableAdminTenants.find((tenant) => tenant.id === state.selectedTenantId) ?? null

      if (fromAvailableTenants) {
        return fromAvailableTenants
      }

      return state.items.find((tenant) => tenant.id === state.selectedTenantId) ?? null
    },
  },

  actions: {
    persistWorkspaceState() {
      writeStorage({
        schemaVersion: 1,
        availableAdminTenants: this.availableAdminTenants,
        selectedTenantId: this.selectedTenantId,
        selectedTenantSlug: this.selectedTenantSlug,
      })
    },

    syncSelectedTenant() {
      if (this.selectedTenantId === null) {
        this.selectedTenantSlug = null
        this.persistWorkspaceState()
        return
      }

      const selectedTenant =
        this.availableAdminTenants.find((tenant) => tenant.id === this.selectedTenantId) ??
        this.items.find((tenant) => tenant.id === this.selectedTenantId) ??
        null

      if (!selectedTenant) {
        this.selectedTenantId = null
        this.selectedTenantSlug = null
        this.persistWorkspaceState()
        return
      }

      this.selectedTenantSlug = selectedTenant.slug
      this.persistWorkspaceState()
    },

    setAvailableAdminTenants(tenants: Tenant[]) {
      this.availableAdminTenants = tenants
      this.syncSelectedTenant()
    },

    setSelectedTenant(tenant: Pick<Tenant, 'id' | 'slug'> | null) {
      this.selectedTenantId = tenant?.id ?? null
      this.selectedTenantSlug = tenant?.slug ?? null
      this.persistWorkspaceState()
    },

    clearSelectedTenant() {
      this.selectedTenantId = null
      this.selectedTenantSlug = null
      this.persistWorkspaceState()
    },

    hydrateSelectedTenantFromAuth(tenant: Pick<Tenant, 'id' | 'slug'> | null) {
      if (!tenant) {
        this.clearSelectedTenant()
        return
      }

      this.setSelectedTenant(tenant)
    },

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
        this.setAvailableAdminTenants(this.items)
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
        this.setAvailableAdminTenants(this.items)
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
        this.setAvailableAdminTenants(this.items)
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

          const adminTenantIndex = this.availableAdminTenants.findIndex((item) => item.id === tenant.id)

          if (adminTenantIndex >= 0) {
            this.availableAdminTenants.splice(adminTenantIndex, 1, tenant)
          }

          if (this.selectedTenantId === tenant.id) {
            this.selectedTenantSlug = tenant.slug
            this.persistWorkspaceState()
          }
        }

        return result
      } finally {
        this.loading = false
      }
    },
  },
})
