import { investorRepository } from '../repositories/investorRepository'
import type {
  InvestorBalance,
  Investor,
  InvestorCreateInput,
  InvestorDeleteInput,
  InvestorServiceResult,
  InvestorTransaction,
  InvestorTransactionCreateInput,
  ShipmentInvestmentDeleteInput,
  ShipmentInvestment,
  ShipmentInvestmentCreateInput,
  ShipmentInvestmentUpdateInput,
  InvestorUpdateInput,
} from '../types'

const listInvestorsByTenant = async (
  tenantId: number,
): Promise<InvestorServiceResult<Investor[]>> => {
  try {
    const data = await investorRepository.listInvestorsByTenant(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load investors.',
    }
  }
}

const listInvestorBalancesByTenant = async (
  tenantId: number,
): Promise<InvestorServiceResult<InvestorBalance[]>> => {
  try {
    const data = await investorRepository.listInvestorBalancesByTenant(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load investor balances.',
    }
  }
}

const createInvestor = async (
  payload: InvestorCreateInput,
): Promise<InvestorServiceResult<Investor>> => {
  try {
    const data = await investorRepository.createInvestor(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create investor.',
    }
  }
}

const updateInvestor = async (
  payload: InvestorUpdateInput,
): Promise<InvestorServiceResult<Investor>> => {
  try {
    const data = await investorRepository.updateInvestor(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update investor.',
    }
  }
}

const deleteInvestor = async (
  payload: InvestorDeleteInput,
): Promise<InvestorServiceResult<null>> => {
  try {
    await investorRepository.deleteInvestor(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete investor.',
    }
  }
}

const listTransactionsByTenant = async (
  tenantId: number,
): Promise<InvestorServiceResult<InvestorTransaction[]>> => {
  try {
    const data = await investorRepository.listTransactionsByTenant(tenantId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load investor transactions.',
    }
  }
}

const createTransaction = async (
  payload: InvestorTransactionCreateInput,
): Promise<InvestorServiceResult<InvestorTransaction>> => {
  try {
    const data = await investorRepository.createTransaction(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create investor transaction.',
    }
  }
}

const listShipmentInvestmentsByShipment = async (
  tenantId: number,
  shipmentId: number,
): Promise<InvestorServiceResult<ShipmentInvestment[]>> => {
  try {
    const data = await investorRepository.listShipmentInvestmentsByShipment(
      tenantId,
      shipmentId,
    )

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load shipment investments.',
    }
  }
}

const createShipmentInvestment = async (
  payload: ShipmentInvestmentCreateInput,
): Promise<InvestorServiceResult<ShipmentInvestment>> => {
  try {
    const data = await investorRepository.createShipmentInvestment(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to create shipment investment.',
    }
  }
}

const updateShipmentInvestment = async (
  payload: ShipmentInvestmentUpdateInput,
): Promise<InvestorServiceResult<ShipmentInvestment>> => {
  try {
    const data = await investorRepository.updateShipmentInvestment(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to update shipment investment.',
    }
  }
}

const deleteShipmentInvestment = async (
  payload: ShipmentInvestmentDeleteInput,
): Promise<InvestorServiceResult<null>> => {
  try {
    await investorRepository.deleteShipmentInvestment(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to delete shipment investment.',
    }
  }
}

const updateShipmentInvestmentCostShare = async (payload: {
  id: number
  cost_share_pct: number
}): Promise<InvestorServiceResult<ShipmentInvestment>> => {
  try {
    const data = await investorRepository.updateShipmentInvestmentCostShare(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to update shipment investment cost share.',
    }
  }
}

export const investorService = {
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
