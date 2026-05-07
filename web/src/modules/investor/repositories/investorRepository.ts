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
  const { data, error } = await supabase
    .from('investors')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('id', { ascending: true })

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
  const { data, error } = await supabase
    .from('investors')
    .insert([
      {
        tenant_id: payload.tenant_id,
        name: payload.name.trim(),
        phone: payload.phone?.trim() || null,
        email: payload.email?.trim() || null,
        address: payload.address?.trim() || null,
      },
    ])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Investor was not created.')
  }

  return data as Investor
}

const updateInvestor = async (payload: InvestorUpdateInput): Promise<Investor> => {
  const { data, error } = await supabase
    .from('investors')
    .update({
      name: payload.name.trim(),
      phone: payload.phone?.trim() || null,
      email: payload.email?.trim() || null,
      address: payload.address?.trim() || null,
    })
    .eq('id', payload.id)
    .eq('tenant_id', payload.tenant_id)
    .select()
    .single()

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
  const { data, error } = await supabase
    .from('investor_transactions')
    .insert([
      {
        tenant_id: payload.tenant_id,
        investor_id: payload.investor_id,
        amount: payload.amount,
        date: payload.date,
        method: payload.method,
        type: payload.type,
        note: payload.note?.trim() || null,
      },
    ])
    .select('*')
    .single()

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
    .eq('shipment_id', shipmentId)
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
        shipment_id: payload.shipment_id,
        investor_id: payload.investor_id,
        invested_amount: payload.invested_amount,
        actual_profit: payload.actual_profit ?? 0,
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

  return data as ShipmentInvestment
}

const updateShipmentInvestment = async (
  payload: ShipmentInvestmentUpdateInput,
): Promise<ShipmentInvestment> => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .update({
      shipment_id: payload.shipment_id,
      investor_id: payload.investor_id,
      invested_amount: payload.invested_amount,
      actual_profit: payload.actual_profit ?? 0,
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

  return data as ShipmentInvestment
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
}
