import { supabase } from 'src/boot/supabase'
import type { InvestorBootstrapContext, InvestorPortfolioSummary } from '../types'

const getInvestorBootstrapContext = async (tenantId: number): Promise<InvestorBootstrapContext> => {
  const { data, error } = await supabase.rpc('get_investor_bootstrap_context', {
    p_tenant_id: tenantId,
  })

  if (error) {
    throw error
  }

  return data as InvestorBootstrapContext
}

const getInvestorPortfolioSummary = async (investorId: number): Promise<InvestorPortfolioSummary> => {
  const { data, error } = await supabase.rpc('get_investor_portfolio_summary', {
    p_investor_id: investorId,
  })

  if (error) {
    throw error
  }

  return data as InvestorPortfolioSummary
}

const getInvestorDashboardSummary = async (tenantId: number, investorId: number) => {
  const { data, error } = await supabase.rpc('get_investor_dashboard_summary', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
  })

  if (error) {
    throw error
  }

  return data
}

const listInvestorAllocations = async (
  tenantId: number,
  investorId: number,
  limit = 50,
  offset = 0
) => {
  const { data, error } = await supabase.rpc('list_investor_allocations', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
    p_limit: limit,
    p_offset: offset,
  })

  if (error) {
    throw error
  }

  return data
}

const listInvestorTransactions = async (
  tenantId: number,
  investorId: number,
  limit = 50,
  offset = 0
) => {
  const { data, error } = await supabase.rpc('list_investor_transactions', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
    p_limit: limit,
    p_offset: offset,
  })

  if (error) {
    throw error
  }

  return data
}

const getInvestorCapitalReport = async (
  tenantId: number,
  investorId: number,
  startDate: string,
  endDate: string
) => {
  const { data, error } = await supabase.rpc('get_investor_capital_report', {
    p_tenant_id: tenantId,
    p_investor_id: investorId,
    p_start_date: startDate,
    p_end_date: endDate,
  })

  if (error) {
    throw error
  }

  return data
}

export const investorPortalRepository = {
  getInvestorBootstrapContext,
  getInvestorPortfolioSummary,
  getInvestorDashboardSummary,
  listInvestorAllocations,
  listInvestorTransactions,
  getInvestorCapitalReport,
}
