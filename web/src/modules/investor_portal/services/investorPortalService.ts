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

const getDashboardSummary = async (tenantId: number, investorId: number) => {
  try {
    const data = await investorPortalRepository.getInvestorDashboardSummary(tenantId, investorId)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load dashboard summary.',
    }
  }
}

const listAllocations = async (
  tenantId: number,
  investorId: number,
  limit = 50,
  offset = 0
) => {
  try {
    const data = await investorPortalRepository.listInvestorAllocations(tenantId, investorId, limit, offset)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load allocations.',
    }
  }
}

const listTransactions = async (
  tenantId: number,
  investorId: number,
  limit = 50,
  offset = 0
) => {
  try {
    const data = await investorPortalRepository.listInvestorTransactions(tenantId, investorId, limit, offset)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to load transactions.',
    }
  }
}

const getCapitalReport = async (
  tenantId: number,
  investorId: number,
  startDate: string,
  endDate: string
) => {
  try {
    const data = await investorPortalRepository.getInvestorCapitalReport(tenantId, investorId, startDate, endDate)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to generate report.',
    }
  }
}

const getAllocationDetail = async (
  tenantId: number,
  investorId: number,
  globalShipmentId: number
) => {
  try {
    const data = await investorPortalRepository.getAllocationDetail(tenantId, investorId, globalShipmentId)
    return { success: true as const, data }
  } catch (error) {
    return {
      success: false as const,
      error: error instanceof Error ? error.message : 'Failed to retrieve allocation detail.',
    }
  }
}

export const investorPortalService = {
  getBootstrapContext,
  getPortfolioSummary,
  getDashboardSummary,
  listAllocations,
  listTransactions,
  getCapitalReport,
  getAllocationDetail,
}

export type { InvestorBootstrapContext, InvestorPortfolioSummary }
