import { defineStore } from 'pinia'
import { handleApiFailure } from 'src/utils/appFeedback'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import type { CommerceInvoiceDetails, CommerceInvoiceDetailsItem } from '../types'

export interface CommerceInvoiceStoreState {
  invoice: CommerceInvoiceDetails['invoice'] | null
  order: CommerceInvoiceDetails['order'] | null
  items: CommerceInvoiceDetailsItem[]
  loading: boolean
  saving: boolean
  error: string | null
}

export const useCommerceInvoiceStore = defineStore('commerceInvoice', {
  state: (): CommerceInvoiceStoreState => ({
    invoice: null,
    order: null,
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),
  actions: {
    async fetchInvoiceDetails(invoiceId: number) {
      this.loading = true
      this.error = null
      try {
        const result = await commerceInvoiceService.getCommerceInvoiceDetails(invoiceId)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to load commerce invoice details.'
          handleApiFailure(result, this.error)
          return result
        }

        this.invoice = result.data.invoice
        this.order = result.data.order
        this.items = result.data.items
        return result
      } finally {
        this.loading = false
      }
    },

    async updateInvoiceCharges(
      invoiceId: number,
      charges: Parameters<typeof commerceInvoiceService.updateCommerceInvoiceCharges>[1],
    ) {
      this.saving = true
      this.error = null
      try {
        const result = await commerceInvoiceService.updateCommerceInvoiceCharges(invoiceId, charges)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to update invoice charges.'
          handleApiFailure(result, this.error)
          return result
        }

        // Update local state directly with returned invoice and order data from RPC
        this.invoice = {
          ...this.invoice,
          ...result.data.invoice,
          billing_profiles: this.invoice?.billing_profiles ?? null,
        } as CommerceInvoiceDetails['invoice']
        this.order = result.data.order

        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvoiceStatus(invoiceId: number, status: string) {
      this.saving = true
      this.error = null
      try {
        const result = await commerceInvoiceService.updateCommerceInvoiceStatus(invoiceId, status)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to update invoice status.'
          handleApiFailure(result, this.error)
          return result
        }

        if (this.invoice) {
          this.invoice.status = result.data.status
        }
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvoiceItem(
      invoiceId: number,
      orderItemId: number,
      payload: Parameters<typeof commerceInvoiceService.updateCommerceInvoiceItem>[2],
    ) {
      this.saving = true
      this.error = null
      try {
        const result = await commerceInvoiceService.updateCommerceInvoiceItem(invoiceId, orderItemId, payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update commerce invoice item.'
          handleApiFailure(result, this.error)
          return result
        }

        // Refetch details to ensure all totals and stock reservations sync correctly
        await this.fetchInvoiceDetails(invoiceId)
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
