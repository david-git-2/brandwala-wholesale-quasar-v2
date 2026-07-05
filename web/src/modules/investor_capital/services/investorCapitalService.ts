import { investorCapitalRepository } from '../repositories/investorCapitalRepository'
import type { CapitalServiceResult, InvestorBalance, Investor, InvestorTransaction, ShipmentInvestment } from '../types'

const listInvestorProfiles = async (tenantId: number): Promise<CapitalServiceResult<InvestorBalance[]>> => {
  try {
    const data = await investorCapitalRepository.listInvestorProfiles(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load investor profiles.',
    }
  }
}

const upsertInvestorProfile = async (payload: any): Promise<CapitalServiceResult<Investor>> => {
  try {
    const data = await investorCapitalRepository.upsertInvestorProfile(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save investor profile.',
    }
  }
}

const deleteInvestorProfile = async (id: number, tenantId: number): Promise<CapitalServiceResult<void>> => {
  try {
    await investorCapitalRepository.deleteInvestorProfile(id, tenantId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete investor profile.',
    }
  }
}

const listTransactions = async (
  tenantId: number,
  limit = 50,
  offset = 0,
  investorId?: number | null,
  type?: string | null,
  startDate?: string | null,
  endDate?: string | null
): Promise<CapitalServiceResult<InvestorTransaction[]>> => {
  try {
    const data = await investorCapitalRepository.listTransactions(tenantId, limit, offset, investorId, type, startDate, endDate)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load transactions.',
    }
  }
}

const createTransaction = async (payload: any): Promise<CapitalServiceResult<InvestorTransaction>> => {
  try {
    let data: InvestorTransaction
    if (payload.type === 'capital_in') {
      data = await investorCapitalRepository.recordCapitalIn(payload)
    } else if (payload.type === 'withdrawal_paid') {
      data = await investorCapitalRepository.recordWithdrawalPaid(payload)
    } else {
      data = await investorCapitalRepository.recordCapitalAdjustment(payload)
    }
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to record transaction.',
    }
  }
}

const listShipmentInvestmentsByShipment = async (
  tenantId: number,
  globalShipmentId: number
): Promise<CapitalServiceResult<ShipmentInvestment[]>> => {
  try {
    const data = await investorCapitalRepository.listShipmentInvestmentsByShipment(tenantId, globalShipmentId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load shipment investments.',
    }
  }
}

const upsertShipmentInvestment = async (payload: any): Promise<CapitalServiceResult<ShipmentInvestment>> => {
  try {
    const data = await investorCapitalRepository.upsertShipmentInvestment(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save shipment investment.',
    }
  }
}

const deleteShipmentInvestment = async (id: number, tenantId: number): Promise<CapitalServiceResult<void>> => {
  try {
    await investorCapitalRepository.deleteShipmentInvestment(id, tenantId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete shipment investment.',
    }
  }
}

const refreshShipmentInvestorProfits = async (globalShipmentId: number): Promise<CapitalServiceResult<void>> => {
  try {
    await investorCapitalRepository.refreshShipmentInvestorProfits(globalShipmentId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to refresh profits.',
    }
  }
}

const getInvestorCapitalReport = async (
  tenantId: number,
  investorId: number,
  startDate: string,
  endDate: string
): Promise<CapitalServiceResult<any>> => {
  try {
    const data = await investorCapitalRepository.getInvestorCapitalReport(tenantId, investorId, startDate, endDate)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to retrieve report.',
    }
  }
}

export const investorCapitalService = {
  listInvestorProfiles,
  upsertInvestorProfile,
  deleteInvestorProfile,
  listTransactions,
  createTransaction,
  listShipmentInvestmentsByShipment,
  upsertShipmentInvestment,
  deleteShipmentInvestment,
  refreshShipmentInvestorProfits,
  getInvestorCapitalReport,
}
