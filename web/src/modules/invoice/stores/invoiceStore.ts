import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { invoiceService } from '../services/invoiceService'
import type {
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  InvoiceListQuery,
  InvoiceStoreState,
  UpdateInvoiceItemInput,
  UpdateInvoiceInput,
} from '../types/index'

export const useInvoiceStore = defineStore('invoice', {
  state: (): InvoiceStoreState => ({
    invoices: [],
    invoiceItems: [],
    selectedInvoice: null,
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
        if (!result.success) {
          this.error = result.error ?? 'Failed to load invoices.'
          handleApiFailure(result, this.error)
          return result
        }

        this.invoices = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchInvoiceItems(payload: InvoiceListQuery = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceService.listInvoiceItems(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load invoice items.'
          handleApiFailure(result, this.error)
          return result
        }
        this.invoiceItems = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createInvoice(payload: CreateInvoiceInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.createInvoice(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create invoice.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.invoices.unshift(result.data)
        }

        showSuccessNotification('Invoice created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvoice(payload: UpdateInvoiceInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.updateInvoice(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update invoice.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.invoices.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.invoices.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Invoice updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInvoice(id: number) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.deleteInvoice({ id })
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete invoice.'
          handleApiFailure(result, this.error)
          return result
        }

        this.invoices = this.invoices.filter((row) => row.id !== id)
        showSuccessNotification('Invoice deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async createInvoiceItem(payload: CreateInvoiceItemInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.createInvoiceItem(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create invoice item.'
          handleApiFailure(result, this.error)
          return result
        }

        showSuccessNotification('Item added to invoice successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvoiceItem(payload: UpdateInvoiceItemInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.updateInvoiceItem(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update invoice item.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          const index = this.invoiceItems.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) this.invoiceItems.splice(index, 1, result.data)
        }
        showSuccessNotification('Invoice item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInvoiceItem(payload: DeleteInvoiceItemInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.deleteInvoiceItem(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete invoice item.'
          handleApiFailure(result, this.error)
          return result
        }
        this.invoiceItems = this.invoiceItems.filter((row) => row.id !== payload.id)
        showSuccessNotification('Invoice item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
