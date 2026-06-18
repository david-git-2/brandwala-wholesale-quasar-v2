import { acceptHMRUpdate, defineStore } from 'pinia'

import { investorPortalService } from '../services/investorPortalService'
import type { InvestorPortfolioSummary } from '../types'

export const useInvestorPortalStore = defineStore('investorPortal', {
  state: () => ({
    loading: false,
    error: null as string | null,
    portfolio: null as InvestorPortfolioSummary | null,
    investorId: null as number | null,
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

    clear() {
      this.loading = false
      this.error = null
      this.portfolio = null
      this.investorId = null
    },
  },
})

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useInvestorPortalStore, import.meta.hot))
}
