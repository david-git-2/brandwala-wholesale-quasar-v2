import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { investorService } from '../services/investorService'
import type {
  InvestorCreateInput,
  InvestorDeleteInput,
  InvestorStoreState,
  InvestorTransactionCreateInput,
  ShipmentInvestmentDeleteInput,
  ShipmentInvestmentCreateInput,
  ShipmentInvestmentUpdateInput,
  InvestorUpdateInput,
} from '../types'

export const useInvestorStore = defineStore('investor', {
  state: (): InvestorStoreState => ({
    investors: [],
    balancesByInvestorId: {},
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
        const result = await investorService.listInvestorsByTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load investors.'
          handleApiFailure(result, this.error)
          return result
        }

        this.investors = result.data ?? []
        await this.fetchInvestorBalancesByTenant(tenantId)
        return result
      } finally {
        this.loadingInvestors = false
      }
    },

    async createInvestor(payload: InvestorCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorService.createInvestor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create investor.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.investors.push(result.data)
        }
        await this.fetchInvestorBalancesByTenant(payload.tenant_id)

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
        const result = await investorService.updateInvestor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update investor.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.investors.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.investors.splice(index, 1, result.data)
          }
        }
        await this.fetchInvestorBalancesByTenant(payload.tenant_id)

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
        const result = await investorService.deleteInvestor(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete investor.'
          handleApiFailure(result, this.error)
          return result
        }

        this.investors = this.investors.filter((item) => item.id !== payload.id)
        const nextBalances = { ...this.balancesByInvestorId }
        delete nextBalances[payload.id]
        this.balancesByInvestorId = nextBalances
        showSuccessNotification('Investor profile deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchTransactionsByTenant(tenantId: number) {
      this.loadingTransactions = true
      this.error = null

      try {
        const result = await investorService.listTransactionsByTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load investor transactions.'
          handleApiFailure(result, this.error)
          return result
        }

        this.transactions = result.data ?? []
        await this.fetchInvestorBalancesByTenant(tenantId)
        return result
      } finally {
        this.loadingTransactions = false
      }
    },

    async createTransaction(payload: InvestorTransactionCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorService.createTransaction(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create investor transaction.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.transactions.push(result.data)
        }
        await this.fetchInvestorBalancesByTenant(payload.tenant_id)

        showSuccessNotification('Investor transaction created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchInvestorBalancesByTenant(tenantId: number) {
      const result = await investorService.listInvestorBalancesByTenant(tenantId)

      if (!result.success) {
        this.error = result.error ?? 'Failed to load investor balances.'
        handleApiFailure(result, this.error)
        return result
      }

      const next: InvestorStoreState['balancesByInvestorId'] = {}
      for (const item of result.data ?? []) {
        next[item.investor_id] = item
      }
      this.balancesByInvestorId = next
      return result
    },

    async fetchShipmentInvestmentsByShipment(tenantId: number, shipmentId: number) {
      this.loadingTransactions = true
      this.error = null

      try {
        const result = await investorService.listShipmentInvestmentsByShipment(
          tenantId,
          shipmentId,
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to load shipment investments.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentInvestments = result.data ?? []
        return result
      } finally {
        this.loadingTransactions = false
      }
    },

    async createShipmentInvestment(payload: ShipmentInvestmentCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorService.createShipmentInvestment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create shipment investment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.shipmentInvestments.push(result.data)
        }

        await this.fetchInvestorBalancesByTenant(payload.tenant_id)
        showSuccessNotification('Shipment investment added successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateShipmentInvestment(payload: ShipmentInvestmentUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorService.updateShipmentInvestment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update shipment investment.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.shipmentInvestments.findIndex((item) => item.id === result.data?.id)
          if (index >= 0) {
            this.shipmentInvestments.splice(index, 1, result.data)
          }
        }

        await this.fetchInvestorBalancesByTenant(payload.tenant_id)
        showSuccessNotification('Shipment investment updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteShipmentInvestment(payload: ShipmentInvestmentDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await investorService.deleteShipmentInvestment(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete shipment investment.'
          handleApiFailure(result, this.error)
          return result
        }

        this.shipmentInvestments = this.shipmentInvestments.filter((item) => item.id !== payload.id)
        await this.fetchInvestorBalancesByTenant(payload.tenant_id)
        showSuccessNotification('Shipment investment deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
