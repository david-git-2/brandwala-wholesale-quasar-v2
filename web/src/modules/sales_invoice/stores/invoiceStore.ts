import { defineStore } from 'pinia'
import { invoiceRepository } from '../repositories/invoiceRepository'
import type { InvoiceBrand, CreateInvoiceBrandInput } from '../repositories/invoiceRepository'
import type { CreateGlobalInvoiceInput, GlobalInvoiceCreated, GlobalInvoiceRow } from 'src/modules/global/types'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'

type InvoiceStoreState = {
  rows: GlobalInvoiceRow[]
  loading: boolean
  saving: boolean
  error: string | null
  brands: (InvoiceBrand & { tenants?: { name: string } })[]
}

const toInvoiceRow = (invoice: GlobalInvoiceCreated): GlobalInvoiceRow => ({
  id: invoice.id,
  tenant_id: invoice.tenant_id,
  parent_tenant_id: invoice.parent_tenant_id,
  invoice_no: invoice.invoice_no,
  invoice_type: invoice.invoice_type,
  invoice_status: invoice.invoice_status,
  payment_status: invoice.payment_status,
  invoice_date: invoice.invoice_date,
  total_amount: invoice.total_amount,
  due_amount: invoice.due_amount,
  paid_amount: invoice.paid_amount,
  billing_profile_id: invoice.billing_profile_id,
  recipient_name: invoice.recipient_name,
})

export const useInvoiceStore = defineStore('salesInvoice', {
  state: (): InvoiceStoreState => ({
    rows: [],
    loading: false,
    saving: false,
    error: null,
    brands: [],
  }),

  actions: {
    async fetchInvoices(parentTenantId: number) {
      this.loading = true
      this.error = null
      try {
        this.rows = await invoiceRepository.listGlobalInvoices(parentTenantId)
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load invoices.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async createInvoice(payload: CreateGlobalInvoiceInput) {
      this.saving = true
      this.error = null
      try {
        const created = await invoiceRepository.createGlobalInvoice(payload)
        const row = toInvoiceRow(created)
        this.rows = [row, ...this.rows.filter((existing) => existing.id !== row.id)]
        return { success: true as const, data: created }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to create invoice.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.saving = false
      }
    },

    async fetchInvoiceBrands(payload: { tenant_id?: number } = {}) {
      this.loading = true
      this.error = null
      try {
        const result = await invoiceRepository.listInvoiceBrands(payload)
        this.brands = result
        return { success: true as const, data: result }
      } catch (error: any) {
        const message = error.message || 'Failed to load brands.'
        this.error = message
        handleApiFailure(error, message)
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async createInvoiceBrand(payload: CreateInvoiceBrandInput) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceRepository.createInvoiceBrand(payload)
        showSuccessNotification('Brand created successfully.')
        return { success: true as const, data: result }
      } catch (error: any) {
        const message = error.message || 'Failed to create brand.'
        this.error = message
        handleApiFailure(error, message)
        return { success: false as const, error: message }
      } finally {
        this.saving = false
      }
    },

    async updateInvoiceBrand(payload: { id: number; patch: Partial<Omit<InvoiceBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }) {
      this.saving = true
      this.error = null
      try {
        const result = await invoiceRepository.updateInvoiceBrand(payload)
        showSuccessNotification('Brand updated successfully.')
        return { success: true as const, data: result }
      } catch (error: any) {
        const message = error.message || 'Failed to update brand.'
        this.error = message
        handleApiFailure(error, message)
        return { success: false as const, error: message }
      } finally {
        this.saving = false
      }
    },

    async deleteInvoiceBrand(payload: { id: number }) {
      this.saving = true
      this.error = null
      try {
        await invoiceRepository.deleteInvoiceBrand(payload)
        this.brands = this.brands.filter((b) => b.id !== payload.id)
        showSuccessNotification('Brand deleted successfully.')
        return { success: true as const }
      } catch (error: any) {
        const message = error.message || 'Failed to delete brand.'
        this.error = message
        handleApiFailure(error, message)
        return { success: false as const, error: message }
      } finally {
        this.saving = false
      }
    },
  },
})

