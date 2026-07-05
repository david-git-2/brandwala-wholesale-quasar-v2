import { supabase } from 'src/boot/supabase'

import type {
  InvestorBalance,
  Investor,
  InvestorCreateInput,
  InvestorDeleteInput,
  InvestorTransaction,
  InvestorTransactionCreateInput,
  ShipmentInvestmentDeleteInput,
  ShipmentInvestment,
  ShipmentInvestmentCreateInput,
  ShipmentInvestmentUpdateInput,
  InvestorUpdateInput,
} from '../types'

const listInvestorsByTenant = async (tenantId: number): Promise<Investor[]> => {
  const { data, error } = await supabase.rpc('list_investor_profiles', {
    p_tenant_id: tenantId,
    p_limit: 1000,
  })

  if (error) {
    throw error
  }

  return (data as Investor[] | null) ?? []
}

const listInvestorBalancesByTenant = async (
  tenantId: number,
): Promise<InvestorBalance[]> => {
  const { data, error } = await supabase
    .from('investor_balances')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as InvestorBalance[] | null) ?? []
}

const createInvestor = async (payload: InvestorCreateInput): Promise<Investor> => {
  const { data, error } = await supabase.rpc('upsert_investor_profile', {
    p_id: null,
    p_tenant_id: payload.tenant_id,
    p_name: payload.name.trim(),
    p_phone: payload.phone?.trim() || null,
    p_email: payload.email?.trim() || null,
    p_address: payload.address?.trim() || null,
    p_is_active: true,
    p_currency_code: 'BDT',
    p_notes: null,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Investor was not created.')
  }

  return data as Investor
}

const updateInvestor = async (payload: InvestorUpdateInput): Promise<Investor> => {
  const { data, error } = await supabase.rpc('upsert_investor_profile', {
    p_id: payload.id,
    p_tenant_id: payload.tenant_id,
    p_name: payload.name.trim(),
    p_phone: payload.phone?.trim() || null,
    p_email: payload.email?.trim() || null,
    p_address: payload.address?.trim() || null,
    p_is_active: true,
    p_currency_code: 'BDT',
    p_notes: null,
  })

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Investor was not updated.')
  }

  return data as Investor
}

const deleteInvestor = async (payload: InvestorDeleteInput): Promise<void> => {
  const { error } = await supabase
    .from('investors')
    .delete()
    .eq('id', payload.id)
    .eq('tenant_id', payload.tenant_id)

  if (error) {
    throw error
  }
}

const listTransactionsByTenant = async (
  tenantId: number,
): Promise<InvestorTransaction[]> => {
  const { data, error } = await supabase
    .from('investor_transactions')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as InvestorTransaction[] | null) ?? []
}

const createTransaction = async (
  payload: InvestorTransactionCreateInput,
): Promise<InvestorTransaction> => {
  let data: any
  let error: any

  if (payload.type === 'deposit' || payload.type === 'capital_in') {
    const res = await supabase.rpc('record_investor_capital_in', {
      p_tenant_id: payload.tenant_id,
      p_investor_id: payload.investor_id,
      p_amount: payload.amount,
      p_date: payload.date,
      p_method: payload.method,
      p_note: payload.note || null,
    })
    data = res.data
    error = res.error
  } else if (payload.type === 'withdrawal' || payload.type === 'withdrawal_paid') {
    const res = await supabase.rpc('record_investor_withdrawal_paid', {
      p_tenant_id: payload.tenant_id,
      p_investor_id: payload.investor_id,
      p_amount: payload.amount,
      p_date: payload.date,
      p_method: payload.method,
      p_note: payload.note || null,
    })
    data = res.data
    error = res.error
  } else {
    const res = await supabase.rpc('record_investor_capital_adjustment', {
      p_tenant_id: payload.tenant_id,
      p_investor_id: payload.investor_id,
      p_amount: payload.amount,
      p_date: payload.date,
      p_method: payload.method,
      p_note: payload.note || null,
    })
    data = res.data
    error = res.error
  }

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Investor transaction was not created.')
  }

  return data as InvestorTransaction
}

const listShipmentInvestmentsByShipment = async (
  tenantId: number,
  shipmentId: number,
): Promise<ShipmentInvestment[]> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('global_shipment_id', shipmentId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as ShipmentInvestment[] | null) ?? []
}

const createShipmentInvestment = async (
  payload: ShipmentInvestmentCreateInput,
): Promise<ShipmentInvestment> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .insert([
      {
        tenant_id: payload.tenant_id,
        global_shipment_id: payload.shipment_id,
        investor_id: payload.investor_id,
        invested_amount: payload.invested_amount,
        status: payload.status ?? 'active',
      },
    ])
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment investment was not created.')
  }

  // Refresh profits
  await supabase.rpc('refresh_shipment_investor_profits', {
    p_global_shipment_id: payload.shipment_id,
  })

  // Select again to get refreshed values
  const { data: updatedData } = await supabase
    .from('shipment_investments')
    .select('*')
    .eq('id', data.id)
    .single()

  return (updatedData ?? data) as ShipmentInvestment
}

const updateShipmentInvestment = async (
  payload: ShipmentInvestmentUpdateInput,
): Promise<ShipmentInvestment> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .update({
      investor_id: payload.investor_id,
      invested_amount: payload.invested_amount,
      status: payload.status ?? 'active',
    })
    .eq('id', payload.id)
    .eq('tenant_id', payload.tenant_id)
    .select('*')
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Shipment investment was not updated.')
  }

  // Refresh profits
  await supabase.rpc('refresh_shipment_investor_profits', {
    p_global_shipment_id: payload.shipment_id,
  })

  // Select again to get refreshed values
  const { data: updatedData } = await supabase
    .from('shipment_investments')
    .select('*')
    .eq('id', data.id)
    .single()

  return (updatedData ?? data) as ShipmentInvestment
}

const deleteShipmentInvestment = async (
  payload: ShipmentInvestmentDeleteInput,
): Promise<void> => {
  const { error } = await supabase
    .from('shipment_investments')
    .delete()
    .eq('id', payload.id)
    .eq('tenant_id', payload.tenant_id)

  if (error) {
    throw error
  }
}

const updateShipmentInvestmentCostShare = async (payload: {
  id: number
  cost_share_pct: number
}): Promise<ShipmentInvestment> => {
  const { data: current } = await supabase
    .from('shipment_investments')
    .select('global_shipment_id, tenant_id, investor_id')
    .eq('id', payload.id)
    .single()

  if (!current) {
    throw new Error('Investment not found')
  }

  const { data, error } = await supabase.rpc('upsert_shipment_investment', {
    p_id: payload.id,
    p_tenant_id: current.tenant_id,
    p_global_shipment_id: current.global_shipment_id,
    p_investor_id: current.investor_id,
    p_cost_share_pct: payload.cost_share_pct,
  })

  if (error) {
    throw error
  }

  return data as ShipmentInvestment
}

export const investorRepository = {
  listInvestorsByTenant,
  listInvestorBalancesByTenant,
  createInvestor,
  updateInvestor,
  deleteInvestor,
  listTransactionsByTenant,
  createTransaction,
  listShipmentInvestmentsByShipment,
  createShipmentInvestment,
  updateShipmentInvestment,
  deleteShipmentInvestment,
  updateShipmentInvestmentCostShare,
}
