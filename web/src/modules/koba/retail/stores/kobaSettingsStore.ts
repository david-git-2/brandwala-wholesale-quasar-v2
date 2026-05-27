import { defineStore } from 'pinia'
import { kobaSettingsRepository, type KobaRetailSettings } from '../repositories/kobaSettingsRepository'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

interface State {
  settings: KobaRetailSettings | null
  loading: boolean
  error: string | null
}

export const useKobaSettingsStore = defineStore('kobaSettings', {
  state: (): State => ({
    settings: null,
    loading: false,
    error: null,
  }),

  actions: {
    async fetchSettings() {
      const authStore = useAuthStore()
      const tenantId = authStore.tenantId

      if (!tenantId) {
        this.error = 'No active tenant ID found'
        return
      }

      // If settings are already loaded for the current active tenant, don't refetch
      if (this.settings && this.settings.tenant_id === tenantId) {
        return
      }
      
      this.loading = true
      this.error = null

      try {
        const { data, error } = await kobaSettingsRepository.getSettings(tenantId)

        if (error) {
          this.error = error.message
          return
        }

        if (data) {
          this.settings = data
        } else {
          // If no settings exist for the tenant, initialize with defaults locally to prevent crashes
          this.settings = {
            id: 0,
            tenant_id: tenantId,
            cod_charge_pct: 1.00,
            gateway_charge_flat: 20.00,
            packing_charge_flat: 37.00,
            invoice_charge_flat: 1.00,
            extra_profit_user_pct: 90.00,
            extra_profit_company_pct: 10.00,
            delivery_rates: { "default": 110, "Dhaka": 100, "Dhaka Sub-Urban": 100 },
            updated_at: new Date().toISOString()
          }
        }
      } catch (err: unknown) {
        this.error = err instanceof Error ? err.message : 'An unexpected error occurred'
      } finally {
        this.loading = false
      }
    },

    async updateSettings(updates: Partial<KobaRetailSettings>) {
      if (!this.settings) return

      const authStore = useAuthStore()
      const tenantId = authStore.tenantId
      if (!tenantId) {
        this.error = 'No active tenant ID found'
        return false
      }

      this.loading = true
      this.error = null

      try {
        const payload = { 
          ...updates, 
          id: this.settings.id,
          tenant_id: tenantId
        }
        const { data, error } = await kobaSettingsRepository.updateSettings(payload)

        if (error) {
          this.error = error.message
          return false
        }

        if (data) {
          this.settings = data
          return true
        }
      } catch (err: unknown) {
        this.error = err instanceof Error ? err.message : 'An unexpected error occurred'
      } finally {
        this.loading = false
      }
      return false
    }
  }
})
