export type InvestorPortfolioBalances = {
  deposits: number
  withdrawals: number
  deployed: number
  available: number
  payouts: number
}

export type InvestorShipmentInvestment = {
  id: number
  shipment_id: number
  investor_id: number
  invested_amount: number
  cost_share_pct: number | null
  allocated_cost: number
  computed_profit: number
  profit_status: string
  status: string
}

export type InvestorPortfolioSummary = {
  investor: {
    id: number
    name: string
    email: string | null
    phone: string | null
  }
  balances: InvestorPortfolioBalances
  active_investments: InvestorShipmentInvestment[]
}

export type InvestorBootstrapContext = {
  authenticated: boolean
  tenant: {
    id: number
    name: string
    slug: string
  } | null
  investor_account?: {
    id: number
    investor_id: number
    email: string
    tenant_id: number
  }
  portfolio?: InvestorPortfolioSummary
  module_keys?: string[]
}
