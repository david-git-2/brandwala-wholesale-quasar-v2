import { defineStore } from 'pinia'

import { globalRepository } from '../repositories/globalRepository'
import type { CreateGlobalInvoiceInput, GlobalInvoiceCreated, GlobalInvoiceRow } from '../types'

type GlobalInvoiceStoreState = {
  rows: GlobalInvoiceRow[]
  loading: boolean
  saving: boolean
  error: string | null
}

const toInvoiceRow = (invoice: GlobalInvoiceCreated): GlobalInvoiceRow => ({
  id: invoice.id,
  tenant_id: invoice.tenant_id,
  parent_tenant_id: invoice.parent_tenant_id,
  invoice_no: invoice.invoice_no,
  invoice_type: invoice.invoice_type,
  payment_status: invoice.payment_status,
  invoice_date: invoice.invoice_date,
  total_amount: invoice.total_amount,
  due_amount: invoice.due_amount,
  paid_amount: invoice.paid_amount,
  billing_profile_id: invoice.billing_profile_id,
  recipient_name: invoice.recipient_name,
})

export const useGlobalInvoiceStore = defineStore('globalInvoice', {
  state: (): GlobalInvoiceStoreState => ({
    rows: [],
    loading: false,
    saving: false,
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

    async createInvoice(payload: CreateGlobalInvoiceInput) {
      this.saving = true
      this.error = null
      try {
        const created = await globalRepository.createGlobalInvoice(payload)
        const row = toInvoiceRow(created)
        this.rows = [row, ...this.rows.filter((existing) => existing.id !== row.id)]
        return { success: true as const, data: created }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to create global invoice.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.saving = false
      }
    },
  },
})
