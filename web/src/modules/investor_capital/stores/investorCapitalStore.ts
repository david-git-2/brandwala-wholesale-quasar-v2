import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { investorCapitalService } from '../services/investorCapitalService'
import type {
  InvestorCapitalState,
  InvestorCreateInput,
  InvestorUpdateInput,
  InvestorDeleteInput,
  InvestorTransactionCreateInput,
  ShipmentInvestmentDeleteInput,
} from '../types'

export const useInvestorCapitalStore = defineStore('investorCapital', {
  state: (): InvestorCapitalState => ({
    investors: [],
    transactions: [],
    shipmentInvestments: [],
    loadingInvestors: false,
    loadingTransactions: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchInvestorsByTenant(tenantId: number) {
      this.loadingInvestors = true
      this.error = null

      try {
        const result = await investorCapitalService.listInvestorProfiles(tenantId)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        this.investors = result.data ?? []
        return result
      } finally {
        this.loadingInvestors = false
      }
    },

    async createInvestor(payload: InvestorCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.upsertInvestorProfile(payload)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchInvestorsByTenant(payload.tenant_id)
        showSuccessNotification('Investor profile created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateInvestor(payload: InvestorUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.upsertInvestorProfile(payload)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        await this.fetchInvestorsByTenant(payload.tenant_id)
        showSuccessNotification('Investor profile updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteInvestor(payload: InvestorDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.deleteInvestorProfile(payload.id, payload.tenant_id)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        this.investors = this.investors.filter((item) => item.investor_id !== payload.id)
        showSuccessNotification('Investor profile deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchTransactionsByTenant(
      tenantId: number,
      limit = 200,
      offset = 0,
      investorId?: number | null,
      type?: string | null,
      startDate?: string | null,
      endDate?: string | null
    ) {
      this.loadingTransactions = true
      this.error = null

      try {
        const result = await investorCapitalService.listTransactions(tenantId, limit, offset, investorId, type, startDate, endDate)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        this.transactions = result.data ?? []
        return result
      } finally {
        this.loadingTransactions = false
      }
    },

    async createTransaction(payload: InvestorTransactionCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.createTransaction(payload)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        await Promise.all([
          this.fetchInvestorsByTenant(payload.tenant_id),
          this.fetchTransactionsByTenant(payload.tenant_id)
        ])

        showSuccessNotification('Investor transaction created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchShipmentInvestmentsByShipment(tenantId: number, globalShipmentId: number) {
      this.loadingTransactions = true
      this.error = null

      try {
        const result = await investorCapitalService.listShipmentInvestmentsByShipment(
          tenantId,
          globalShipmentId
        )

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentInvestments = result.data ?? []
        return result
      } finally {
        this.loadingTransactions = false
      }
    },

    async upsertShipmentInvestment(payload: {
      id?: number | null
      tenant_id: number
      global_shipment_id: number
      investor_id: number
      cost_share_pct: number
    }) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.upsertShipmentInvestment(payload)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        await Promise.all([
          this.fetchInvestorsByTenant(payload.tenant_id),
          this.fetchShipmentInvestmentsByShipment(payload.tenant_id, payload.global_shipment_id)
        ])

        showSuccessNotification('Shipment allocation cost share updated.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteShipmentInvestment(payload: ShipmentInvestmentDeleteInput & { global_shipment_id: number }) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.deleteShipmentInvestment(payload.id, payload.tenant_id)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        // Trigger profit refresh
        await investorCapitalService.refreshShipmentInvestorProfits(payload.global_shipment_id)

        await Promise.all([
          this.fetchInvestorsByTenant(payload.tenant_id),
          this.fetchShipmentInvestmentsByShipment(payload.tenant_id, payload.global_shipment_id)
        ])

        showSuccessNotification('Shipment investment deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async refreshProfits(tenantId: number, globalShipmentId: number) {
      this.saving = true
      this.error = null

      try {
        const result = await investorCapitalService.refreshShipmentInvestorProfits(globalShipmentId)

        if (!result.success) {
          this.error = result.error
          handleApiFailure(result, this.error)
          return result
        }

        await Promise.all([
          this.fetchInvestorsByTenant(tenantId),
          this.fetchShipmentInvestmentsByShipment(tenantId, globalShipmentId)
        ])

        showSuccessNotification('Profit allocations refreshed successfully.')
        return result
      } finally {
        this.saving = false
      }
    }
  }
})
