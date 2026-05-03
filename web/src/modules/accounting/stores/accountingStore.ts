import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { accountingService } from '../services/accountingService'
import type {
  AccountingListQuery,
  AccountingStoreState,
  CreateInventoryAccountingEntryInput,
  CreateInvoiceAccountingPaymentInput,
  DeleteInventoryAccountingEntryInput,
  DeleteInvoiceAccountingPaymentInput,
  UpdateInventoryAccountingEntryInput,
  UpdateInvoiceAccountingPaymentInput,
} from '../types'

export const useAccountingStore = defineStore('accounting', {
  state: (): AccountingStoreState => ({
    accountingEntries: [],
    accountingPayments: [],
    loading: false,
    saving: false,
    error: null,
  }),
  actions: {
    async fetchInventoryAccountingEntries(payload: AccountingListQuery = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await accountingService.listInventoryAccountingEntries(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load inventory accounting entries.'
          handleApiFailure(result, this.error)
          return result
        }
        this.accountingEntries = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },
    async createInventoryAccountingEntry(payload: CreateInventoryAccountingEntryInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.createInventoryAccountingEntry(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create inventory accounting entry.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) this.accountingEntries.unshift(result.data)
        showSuccessNotification('Accounting entry created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
    async updateInventoryAccountingEntry(payload: UpdateInventoryAccountingEntryInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.updateInventoryAccountingEntry(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update inventory accounting entry.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          const index = this.accountingEntries.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) this.accountingEntries.splice(index, 1, result.data)
        }
        showSuccessNotification('Accounting entry updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
    async deleteInventoryAccountingEntry(payload: DeleteInventoryAccountingEntryInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.deleteInventoryAccountingEntry(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete inventory accounting entry.'
          handleApiFailure(result, this.error)
          return result
        }
        this.accountingEntries = this.accountingEntries.filter((row) => row.id !== payload.id)
        showSuccessNotification('Accounting entry deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
    async fetchInvoiceAccountingPayments(payload: AccountingListQuery = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await accountingService.listInvoiceAccountingPayments(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load invoice accounting payments.'
          handleApiFailure(result, this.error)
          return result
        }
        this.accountingPayments = result.data?.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },
    async createInvoiceAccountingPayment(payload: CreateInvoiceAccountingPaymentInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.createInvoiceAccountingPayment(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create invoice accounting payment.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) this.accountingPayments.unshift(result.data)
        showSuccessNotification('Invoice accounting payment created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
    async updateInvoiceAccountingPayment(payload: UpdateInvoiceAccountingPaymentInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.updateInvoiceAccountingPayment(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update invoice accounting payment.'
          handleApiFailure(result, this.error)
          return result
        }
        if (result.data) {
          const index = this.accountingPayments.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) this.accountingPayments.splice(index, 1, result.data)
        }
        showSuccessNotification('Invoice accounting payment updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
    async deleteInvoiceAccountingPayment(payload: DeleteInvoiceAccountingPaymentInput) {
      this.saving = true
      this.error = null
      try {
        const result = await accountingService.deleteInvoiceAccountingPayment(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete invoice accounting payment.'
          handleApiFailure(result, this.error)
          return result
        }
        this.accountingPayments = this.accountingPayments.filter((row) => row.id !== payload.id)
        showSuccessNotification('Invoice accounting payment deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
