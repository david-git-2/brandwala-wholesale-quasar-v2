export interface BatchPnlInput {
  landedCost: number
  grossProfit: number
}

export interface TransactionInput {
  type: string
  amount: number
}

export interface AllocationInput {
  cost_share_pct: number | null
  computed_profit: number
  profit_status: 'open' | 'partial' | 'realized'
}

/**
 * Calculates the investor's allocated cost and computed profit based on batch P&L and cost share %.
 */
export const investorShare = (
  batchPnl: BatchPnlInput,
  costSharePct: number
): { allocated_cost: number; computed_profit: number } => {
  const costShare = costSharePct ?? 0
  return {
    allocated_cost: Number((batchPnl.landedCost * costShare / 100).toFixed(2)),
    computed_profit: Number((batchPnl.grossProfit * costShare / 100).toFixed(2)),
  }
}

/**
 * Sums all incoming capital transactions (capital_in, capital_adjustment, and legacy deposit).
 */
export const totalCapitalIn = (transactions: TransactionInput[]): number => {
  return Number(
    transactions
      .filter((tx) => ['capital_in', 'capital_adjustment', 'deposit'].includes(tx.type))
      .reduce((sum, tx) => sum + Number(tx.amount), 0)
      .toFixed(2)
  )
}

/**
 * Calculates withdrawable balance.
 * Formula: realizedProfit - withdrawn
 */
export const withdrawableBalance = (realizedProfit: number, withdrawn: number): number => {
  return Number((realizedProfit - withdrawn).toFixed(2))
}

/**
 * Calculates unrealized profit across allocations.
 * Sums computed_profit where profit_status is open or partial.
 */
export const unrealizedProfit = (allocations: AllocationInput[]): number => {
  return Number(
    allocations
      .filter((a) => ['open', 'partial'].includes(a.profit_status))
      .reduce((sum, a) => sum + Number(a.computed_profit), 0)
      .toFixed(2)
  )
}

/**
 * Calculates parent's remaining cost-share percentage.
 * Formula: 100 - sum of cost_share_pct
 */
export const parentRemainderPct = (allocations: { cost_share_pct: number | null }[]): number => {
  const sumShare = allocations.reduce((sum, a) => sum + (a.cost_share_pct ?? 0), 0)
  return Number(Math.max(100 - sumShare, 0).toFixed(2))
}
