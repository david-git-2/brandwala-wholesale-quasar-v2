import { defineStore } from 'pinia'
import { handleApiFailure } from 'src/utils/appFeedback'
import { invoiceService } from '../services/invoiceService'
import type { InvoiceListQuery, InvoiceStoreState } from '../types'

export const useInvoiceStore = defineStore('invoice', {
  state: (): InvoiceStoreState => ({
    invoices: [],
    invoiceItems: [],
    accountingEntries: [],
    payments: [],
    selectedInvoice: null,
    selectedInvoiceItem: null,
    selectedAccountingEntry: null,
    selectedPayment: null,
    loading: false,
    saving: false,
    error: null,
  }),
  actions: {
    async fetchInvoices(payload: InvoiceListQuery = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceService.listInvoices(payload)
        if (!result.success) { this.error = result.error ?? 'Failed to load invoices.'; handleApiFailure(result, this.error); return result }
        this.invoices = result.data?.data ?? []
        return result
      } finally { this.loading = false }
    },
  },
})
