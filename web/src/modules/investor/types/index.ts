export type Investor = {
  id: number
  tenant_id: number
  name: string
  phone: string | null
  email: string | null
  address: string | null
  created_at: string
  updated_at: string
}

export type InvestorBalance = {
  id: number
  tenant_id: number
  investor_id: number
  total_deposit: number
  total_withdrawal: number
  total_profit_payout: number
  total_invested_active: number
  available_balance: number
  created_at: string
  updated_at: string
}

export type InvestorCreateInput = {
  tenant_id: number
  name: string
  phone?: string | null
  email?: string | null
  address?: string | null
}

export type InvestorUpdateInput = {
  id: number
  tenant_id: number
  name: string
  phone?: string | null
  email?: string | null
  address?: string | null
}

export type InvestorDeleteInput = {
  id: number
  tenant_id: number
}

export type InvestorTransactionType = 'deposit' | 'withdrawal' | 'profit_payout'

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

export type InvestorServiceResult<T> =
  | {
      success: true
      data: T
    }
  | {
      success: false
      error: string
    }

export type InvestorStoreState = {
  investors: Investor[]
  balancesByInvestorId: Record<number, InvestorBalance>
  transactions: InvestorTransaction[]
  shipmentInvestments: ShipmentInvestment[]
  loadingInvestors: boolean
  loadingTransactions: boolean
  saving: boolean
  error: string | null
}
