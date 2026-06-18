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

export const investorPortalRepository = {
  getInvestorBootstrapContext,
  getInvestorPortfolioSummary,
}
