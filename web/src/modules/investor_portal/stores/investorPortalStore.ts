import { acceptHMRUpdate, defineStore } from 'pinia'

import { investorPortalService } from '../services/investorPortalService'
import type { InvestorPortfolioSummary } from '../types'

export const useInvestorPortalStore = defineStore('investorPortal', {
  state: () => ({
    loading: false,
    error: null as string | null,
    portfolio: null as InvestorPortfolioSummary | null,
    dashboardSummary: null as any | null,
    allocations: [] as any[],
    transactions: [] as any[],
    investorId: null as number | null,
    totalAllocationsCount: 0,
    totalTransactionsCount: 0,
  }),

  actions: {
    async loadPortfolio(investorId: number) {
      this.loading = true
      this.error = null

      const result = await investorPortalService.getPortfolioSummary(investorId)

      this.loading = false

      if (!result.success) {
        this.error = result.error ?? 'Failed to load portfolio.'
        return result
      }

      this.portfolio = result.data
      this.investorId = investorId
      return result
    },

    async fetchDashboardSummary(tenantId: number, investorId: number) {
      this.loading = true
      this.error = null
      const result = await investorPortalService.getDashboardSummary(tenantId, investorId)
      this.loading = false

      if (!result.success) {
        this.error = result.error ?? 'Failed to load dashboard summary.'
        return result
      }

      this.dashboardSummary = result.data
      return result
    },

    async fetchAllocations(tenantId: number, investorId: number, limit = 50, offset = 0) {
      this.loading = true
      this.error = null
      const result = await investorPortalService.listAllocations(tenantId, investorId, limit, offset)
      this.loading = false

      if (!result.success) {
        this.error = result.error ?? 'Failed to load allocations.'
        return result
      }

      this.allocations = result.data ?? []
      this.totalAllocationsCount = result.data?.[0]?.total_count ?? 0
      return result
    },

    async fetchTransactions(tenantId: number, investorId: number, limit = 50, offset = 0) {
      this.loading = true
      this.error = null
      const result = await investorPortalService.listTransactions(tenantId, investorId, limit, offset)
      this.loading = false

      if (!result.success) {
        this.error = result.error ?? 'Failed to load transactions.'
        return result
      }

      this.transactions = result.data ?? []
      this.totalTransactionsCount = result.data?.[0]?.total_count ?? 0
      return result
    },

    async fetchAllocationDetail(tenantId: number, investorId: number, globalShipmentId: number) {
      this.loading = true
      this.error = null
      const result = await investorPortalService.getAllocationDetail(tenantId, investorId, globalShipmentId)
      this.loading = false
      return result
    },

    clear() {
      this.loading = false
      this.error = null
      this.portfolio = null
      this.dashboardSummary = null
      this.allocations = []
      this.transactions = []
      this.investorId = null
      this.totalAllocationsCount = 0
      this.totalTransactionsCount = 0
    },
  },
})

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useInvestorPortalStore, import.meta.hot))
}
