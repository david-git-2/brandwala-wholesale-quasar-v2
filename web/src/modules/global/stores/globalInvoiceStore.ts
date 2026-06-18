import { defineStore } from 'pinia'

import { globalRepository } from '../repositories/globalRepository'
import type { GlobalInvoiceRow } from '../types'

type GlobalInvoiceStoreState = {
  rows: GlobalInvoiceRow[]
  loading: boolean
  error: string | null
}

export const useGlobalInvoiceStore = defineStore('globalInvoice', {
  state: (): GlobalInvoiceStoreState => ({
    rows: [],
    loading: false,
    error: null,
  }),

  actions: {
    async fetchInvoices(parentTenantId: number) {
      this.loading = true
      this.error = null
      try {
        this.rows = await globalRepository.listGlobalInvoices(parentTenantId)
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load global invoices.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },
  },
})
