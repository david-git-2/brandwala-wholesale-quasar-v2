import { investorPortalRepository } from '../repositories/investorPortalRepository'
import type { InvestorBootstrapContext, InvestorPortfolioSummary } from '../types'

const getBootstrapContext = async (tenantId: number) => {
  try {
    const data = await investorPortalRepository.getInvestorBootstrapContext(tenantId)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load investor context.',
    }
  }
}

const getPortfolioSummary = async (investorId: number) => {
  try {
    const data = await investorPortalRepository.getInvestorPortfolioSummary(investorId)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load portfolio.',
    }
  }
}

export const investorPortalService = {
  getBootstrapContext,
  getPortfolioSummary,
}

export type { InvestorBootstrapContext, InvestorPortfolioSummary }
