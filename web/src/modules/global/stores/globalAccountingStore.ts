import { defineStore } from 'pinia'

import { globalRepository } from '../repositories/globalRepository'
import type {
  GlobalInvoiceAccountingRow,
  GlobalLedgerRow,
  GlobalShipmentAccountingRow,
  GlobalShipmentLedgerEntry,
  ParentCashCirculation,
} from '../types'

type GlobalAccountingStoreState = {
  ledgerRows: GlobalLedgerRow[]
  shipmentLedgerRows: GlobalShipmentLedgerEntry[]
  shipmentAccountingRows: GlobalShipmentAccountingRow[]
  invoiceAccountingRows: GlobalInvoiceAccountingRow[]
  cashCirculation: ParentCashCirculation | null
  loading: boolean
  error: string | null
}

export const useGlobalAccountingStore = defineStore('globalAccounting', {
  state: (): GlobalAccountingStoreState => ({
    ledgerRows: [],
    shipmentLedgerRows: [],
    shipmentAccountingRows: [],
    invoiceAccountingRows: [],
    cashCirculation: null,
    loading: false,
    error: null,
  }),

  actions: {
    async fetchLedger(parentTenantId: number, tenantId?: number | null) {
      this.loading = true
      this.error = null
      try {
        this.ledgerRows = []
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load global ledger.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async fetchCashCirculation(parentTenantId: number) {
      try {
        this.cashCirculation = await globalRepository.getParentCashCirculation(parentTenantId)
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load cash circulation.'
        this.error = message
        return { success: false as const, error: message }
      }
    },

    async fetchShipmentAccounting(parentTenantId: number) {
      this.loading = true
      this.error = null
      try {
        this.shipmentAccountingRows = []
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load shipment accounting.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async fetchShipmentLedger(parentTenantId: number, shipmentId: number) {
      this.loading = true
      this.error = null
      try {
        this.shipmentLedgerRows = []
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load shipment ledger.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async refreshShipmentAccounting(parentTenantId: number, shipmentId: number) {
      this.error = 'Retired'
      return { success: false as const, error: 'Retired' }
    },

    async fetchInvoiceAccounting(parentTenantId: number) {
      this.loading = true
      this.error = null
      try {
        this.invoiceAccountingRows = []
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load invoice accounting.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },
  },
})
