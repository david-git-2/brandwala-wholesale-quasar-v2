import { costingFileRepository } from '../repositories/costingFileRepository'
import { costingFileItemService } from './costingFileItemService'
import type {
  CostingFileCreateInput,
  CostingFileDetails,
  CostingFileItem,
  CostingFileItemRequestCreateInput,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileListEntry,
  CostingFilePricingUpdateInput,
  CostingFileServiceResult,
  CostingFileStatusUpdateInput,
} from '../types'

const listCostingFilesForTenant = async (
  tenantId: number,
): Promise<CostingFileServiceResult<CostingFileListEntry[]>> => {
  try {
    const data = await costingFileRepository.listCostingFilesForTenant(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing files.',
    }
  }
}

const listCostingFilesForCustomerGroup = async (
  customerGroupId: number,
): Promise<CostingFileServiceResult<CostingFileListEntry[]>> => {
  try {
    const data = await costingFileRepository.listCostingFilesForCustomerGroup(customerGroupId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing files.',
    }
  }
}

const getCostingFileById = async (
  id: number,
): Promise<CostingFileServiceResult<CostingFileDetails | null>> => {
  try {
    const data = await costingFileRepository.getCostingFileById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing file details.',
    }
  }
}

const listCostingFileItems = async (
  costingFileId: number,
): Promise<CostingFileServiceResult<CostingFileItem[]>> => {
  return costingFileItemService.listCostingFileItems(costingFileId)
}

const createCostingFile = async (
  payload: CostingFileCreateInput,
): Promise<CostingFileServiceResult<CostingFileDetails>> => {
  try {
    const data = await costingFileRepository.createCostingFile(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create costing file.',
    }
  }
}

const createCostingFileItemRequest = async (
  payload: CostingFileItemRequestCreateInput,
): Promise<
  CostingFileServiceResult<
    Pick<
      CostingFileItem,
      'id' | 'costing_file_id' | 'website_url' | 'quantity' | 'status' | 'created_by_email' | 'created_at' | 'updated_at'
    >
  >
> => {
  return costingFileItemService.createCostingFileItemRequest(payload)
}

const updateCostingFileStatus = async (
  payload: CostingFileStatusUpdateInput,
): Promise<CostingFileServiceResult<Pick<CostingFileDetails, 'id' | 'status' | 'updated_at'>>> => {
  try {
    const data = await costingFileRepository.updateCostingFileStatus(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update costing file status.',
    }
  }
}

const updateCostingFilePricing = async (
  payload: CostingFilePricingUpdateInput,
): Promise<
  CostingFileServiceResult<
    Pick<
      CostingFileDetails,
      'id' | 'cargo_rate_1kg' | 'cargo_rate_2kg' | 'conversion_rate' | 'admin_profit_rate' | 'updated_at'
    >
  >
> => {
  try {
    const data = await costingFileRepository.updateCostingFilePricing(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update pricing.',
    }
  }
}

const updateCostingFileItemEnrichment = async (
  payload: CostingFileItemEnrichmentUpdateInput,
): Promise<CostingFileServiceResult<CostingFileItem>> => {
  return costingFileItemService.updateCostingFileItemEnrichment(payload)
}

const updateCostingFileItemCustomerProfit = async (
  payload: CostingFileItemCustomerProfitUpdateInput,
): Promise<
  CostingFileServiceResult<Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>>
> => {
  return costingFileItemService.updateCostingFileItemCustomerProfit(payload)
}

const updateCostingFileItemStatus = async (
  payload: CostingFileItemStatusUpdateInput,
): Promise<CostingFileServiceResult<Pick<CostingFileItem, 'id' | 'status' | 'updated_at'>>> => {
  return costingFileItemService.updateCostingFileItemStatus(payload)
}

const updateCostingFileItemOffer = async (
  payload: CostingFileItemOfferUpdateInput,
): Promise<
  CostingFileServiceResult<
    Pick<CostingFileItem, 'id' | 'offer_price_override_bdt' | 'offer_price_bdt' | 'updated_at'>
  >
> => {
  return costingFileItemService.updateCostingFileItemOffer(payload)
}

export const costingFileService = {
  listCostingFilesForTenant,
  listCostingFilesForCustomerGroup,
  getCostingFileById,
  listCostingFileItems,
  createCostingFile,
  createCostingFileItemRequest,
  updateCostingFileStatus,
  updateCostingFilePricing,
  updateCostingFileItemEnrichment,
  updateCostingFileItemCustomerProfit,
  updateCostingFileItemStatus,
  updateCostingFileItemOffer,
}
