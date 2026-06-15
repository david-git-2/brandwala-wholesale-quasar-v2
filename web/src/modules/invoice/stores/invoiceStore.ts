import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { invoiceService } from '../services/invoiceService'
import type {
  AddPaymentAllocationInput,
  ApplyInvoiceItemReturnInput,
  CreatePaymentWithAllocationsInput,
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  DeletePaymentInput,
  InvoiceListQuery,
  InvoiceStoreState,
  UpdateInvoiceItemInput,
  UpdateInvoiceInput,
  UpdatePaymentInput,
  UpdatePaymentAllocationAmountInput,
  InvoiceBrand,
  CreateInvoiceBrandInput,
  InvoiceBox,
  CreateInvoiceBoxInput,
} from '../types/index'

export const useInvoiceStore = defineStore('invoice', {
  state: (): InvoiceStoreState => ({
    invoices: [],
    invoiceItems: [],
    payments: [],
    paymentAllocations: [],
    selectedInvoice: null,
    loading: false,
    saving: false,
    error: null,
    brands: [],
    boxes: [],
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
    async fetchInvoiceById(id: number) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceService.getInvoiceById(id)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to retrieve invoice.'
          return result
        }
        const index = this.invoices.findIndex((row) => row.id === id)
        if (index >= 0) {
          this.invoices.splice(index, 1, result.data)
        } else {
          this.invoices.push(result.data)
        }
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

    async fetchPayments(payload: InvoiceListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await invoiceService.listPayments(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load payments.'
          handleApiFailure(result, this.error)
          return result
        }

        this.payments = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchPaymentAllocations(payload: InvoiceListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await invoiceService.listPaymentAllocations(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load payment allocations.'
          handleApiFailure(result, this.error)
          return result
        }

        this.paymentAllocations = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createPaymentWithAllocations(payload: CreatePaymentWithAllocationsInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.createPaymentWithAllocations(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create payment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.payments.unshift(result.data)
        }

        showSuccessNotification('Payment saved successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async addPaymentAllocation(payload: AddPaymentAllocationInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.addPaymentAllocation(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to add payment allocation.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          this.paymentAllocations.unshift(result.data)
        }
        showSuccessNotification('Allocation saved successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updatePaymentAllocationAmount(payload: UpdatePaymentAllocationAmountInput) {
      this.saving = true
      this.error = null

      try {
        const result = await invoiceService.updatePaymentAllocationAmount(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update payment allocation.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          const index = this.paymentAllocations.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) this.paymentAllocations.splice(index, 1, result.data)
          else this.paymentAllocations.unshift(result.data)
        }
        showSuccessNotification('Allocation updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updatePayment(payload: UpdatePaymentInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.updatePayment(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update payment.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          const index = this.payments.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) this.payments.splice(index, 1, result.data)
          else this.payments.unshift(result.data)
        }
        showSuccessNotification('Payment updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deletePayment(payload: DeletePaymentInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.deletePayment(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete payment.'
          handleApiFailure(result, this.error)
          return result
        }
        this.payments = this.payments.filter((row) => row.id !== payload.payment_id)
        this.paymentAllocations = this.paymentAllocations.filter((row) => row.payment_id !== payload.payment_id)
        showSuccessNotification('Payment deleted successfully.')
        return result
      } finally {
        this.saving = false
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

    async recomputeInvoicePaymentStatus(invoiceId: number) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.recomputeInvoicePaymentStatus(invoiceId)
        if (!result.success) {
          this.error = result.error ?? 'Failed to recompute invoice payment status.'
          handleApiFailure(result, this.error)
          return result
        }
        return result
      } finally {
        this.saving = false
      }
    },

    async applyInvoiceItemReturn(payload: ApplyInvoiceItemReturnInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.applyInvoiceItemReturn(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to apply invoice item return.'
          handleApiFailure(result, this.error)
          return result
        }
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInvoiceBrands(payload: { tenant_id?: number } = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceService.listInvoiceBrands(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load brands.'
          handleApiFailure(result, this.error)
          return result
        }
        this.brands = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createInvoiceBrand(payload: CreateInvoiceBrandInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.createInvoiceBrand(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create brand.'
          handleApiFailure(result, this.error)
          return result
        }
        showSuccessNotification('Brand created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvoiceBrand(payload: { id: number; patch: Partial<Omit<InvoiceBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.updateInvoiceBrand(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update brand.'
          handleApiFailure(result, this.error)
          return result
        }
        showSuccessNotification('Brand updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInvoiceBrand(payload: { id: number }) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.deleteInvoiceBrand(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete brand.'
          handleApiFailure(result, this.error)
          return result
        }
        this.brands = this.brands.filter((b) => b.id !== payload.id)
        showSuccessNotification('Brand deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInvoiceBoxes(payload: { invoice_id: number; tenant_id?: number }) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceService.listInvoiceBoxes(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load box weights.'
          handleApiFailure(result, this.error)
          return result
        }
        this.boxes = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createInvoiceBox(payload: CreateInvoiceBoxInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.createInvoiceBox(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to add box weight.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          this.boxes.push(result.data)
        }
        showSuccessNotification('Box weight added successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInvoiceBox(payload: { id: number }) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceService.deleteInvoiceBox(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete box weight.'
          handleApiFailure(result, this.error)
          return result
        }
        this.boxes = this.boxes.filter((b) => b.id !== payload.id)
        showSuccessNotification('Box weight deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
