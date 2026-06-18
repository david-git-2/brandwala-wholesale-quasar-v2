import { defineStore } from 'pinia'

import { globalRepository } from '../repositories/globalRepository'
import type {
  GlobalInvoiceAccountingRow,
  GlobalLedgerRow,
  GlobalShipmentAccountingRow,
  ParentCashCirculation,
} from '../types'

type GlobalAccountingStoreState = {
  ledgerRows: GlobalLedgerRow[]
  shipmentAccountingRows: GlobalShipmentAccountingRow[]
  invoiceAccountingRows: GlobalInvoiceAccountingRow[]
  cashCirculation: ParentCashCirculation | null
  loading: boolean
  error: string | null
}

export const useGlobalAccountingStore = defineStore('globalAccounting', {
  state: (): GlobalAccountingStoreState => ({
    ledgerRows: [],
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
        this.ledgerRows = await globalRepository.listGlobalLedger(parentTenantId, tenantId)
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
        this.shipmentAccountingRows = await globalRepository.listGlobalShipmentAccounting(parentTenantId)
        return { success: true as const }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to load shipment accounting.'
        this.error = message
        return { success: false as const, error: message }
      } finally {
        this.loading = false
      }
    },

    async fetchInvoiceAccounting(parentTenantId: number) {
      this.loading = true
      this.error = null
      try {
        this.invoiceAccountingRows = await globalRepository.listGlobalInvoiceAccounting(parentTenantId)
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
