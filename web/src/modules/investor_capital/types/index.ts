export type Investor = {
  id: number
  tenant_id: number
  name: string
  phone: string | null
  email: string | null
  address: string | null
  is_active: boolean
  currency_code: string
  notes: string | null
  created_at: string
  updated_at: string
}

export type InvestorBalance = {
  investor_id: number
  name: string
  email: string | null
  phone: string | null
  address: string | null
  is_active: boolean
  currency_code: string
  notes: string | null
  total_capital_in: number
  total_withdrawn: number
  total_invested_active: number
  available_balance: number
  total_profit_realized: number
  total_profit_unrealized: number
}

export type InvestorCreateInput = {
  tenant_id: number
  name: string
  phone?: string | null
  email?: string | null
  address?: string | null
  is_active?: boolean
  currency_code?: string
  notes?: string | null
}

export type InvestorUpdateInput = {
  id: number
  tenant_id: number
  name: string
  phone?: string | null
  email?: string | null
  address?: string | null
  is_active?: boolean
  currency_code?: string
  notes?: string | null
}

export type InvestorDeleteInput = {
  id: number
  tenant_id: number
}

export type InvestorTransactionType = 'capital_in' | 'withdrawal_paid' | 'capital_adjustment'

export type InvestorTransactionMethod = 'cash' | 'bank' | 'mobile_banking' | 'other'

export type InvestorTransaction = {
  id: number
  tenant_id: number
  investor_id: number
  amount: number
  date: string
  method: InvestorTransactionMethod
  type: InvestorTransactionType
  note: string | null
  created_at: string
  updated_at: string
}

export type InvestorTransactionCreateInput = {
  tenant_id: number
  investor_id: number
  amount: number
  date: string
  method: InvestorTransactionMethod
  type: InvestorTransactionType
  note?: string | null
}

export type ShipmentInvestmentStatus = 'active' | 'closed' | 'cancelled'

export type ShipmentInvestment = {
  id: number
  tenant_id: number
  shipment_id: number
  global_shipment_id: number
  investor_id: number
  invested_amount: number
  actual_profit: number
  cost_share_pct: number | null
  allocated_cost: number
  computed_profit: number
  profit_status: string
  status: ShipmentInvestmentStatus
  created_at: string
  updated_at: string
}

export type ShipmentInvestmentCreateInput = {
  tenant_id: number
  shipment_id: number
  investor_id: number
  invested_amount: number
  actual_profit?: number
  status?: ShipmentInvestmentStatus
}

export type ShipmentInvestmentUpdateInput = {
  id: number
  tenant_id: number
  shipment_id: number
  investor_id: number
  invested_amount: number
  actual_profit?: number
  status?: ShipmentInvestmentStatus
}

export type ShipmentInvestmentDeleteInput = {
  id: number
  tenant_id: number
}

export type CapitalServiceResult<T> =
  | {
      success: true
      data: T
    }
  | {
      success: false
      error: string
    }

export type InvestorCapitalState = {
  investors: InvestorBalance[]
  transactions: InvestorTransaction[]
  shipmentInvestments: ShipmentInvestment[]
  loadingInvestors: boolean
  loadingTransactions: boolean
  saving: boolean
  error: string | null
}
