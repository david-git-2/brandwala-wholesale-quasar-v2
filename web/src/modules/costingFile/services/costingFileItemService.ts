import { costingFileItemRepository } from '../repositories/costingFileItemRepository'
import type {
  CostingFileItem,
  CostingFileItemCreateInput,
  CostingFileItemsCustomerProfitBulkUpdateInput,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemDeleteInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemRequestCreateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileItemUpdateInput,
  CostingFileServiceResult,
} from '../types'

const listCostingFileItems = async (
  costingFileId: number,
): Promise<CostingFileServiceResult<CostingFileItem[]>> => {
  try {
    const data = await costingFileItemRepository.listCostingFileItems(costingFileId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing file items.',
    }
  }
}

const listCostingFileItemsForCustomer = async (
  costingFileId: number,
): Promise<CostingFileServiceResult<CostingFileItem[]>> => {
  try {
    const data = await costingFileItemRepository.listCostingFileItemsForCustomer(costingFileId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing file items.',
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
  try {
    const data = await costingFileItemRepository.createCostingFileItemRequest(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create request item.',
    }
  }
}

const createCostingFileItem = async (
  payload: CostingFileItemCreateInput,
): Promise<CostingFileServiceResult<CostingFileItem>> => {
  try {
    const data = await costingFileItemRepository.createCostingFileItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create costing file item.',
    }
  }
}

const updateCostingFileItemEnrichment = async (
  payload: CostingFileItemEnrichmentUpdateInput,
): Promise<CostingFileServiceResult<CostingFileItem>> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItemEnrichment(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update item enrichment.',
    }
  }
}

const updateCostingFileItemCustomerProfit = async (
  payload: CostingFileItemCustomerProfitUpdateInput,
): Promise<
  CostingFileServiceResult<Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>>
> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItemCustomerProfit(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update customer profit.',
    }
  }
}

const updateCostingFileItemsCustomerProfit = async (
  payload: CostingFileItemsCustomerProfitBulkUpdateInput,
): Promise<
  CostingFileServiceResult<Array<Pick<CostingFileItem, 'id' | 'customer_profit_rate' | 'updated_at'>>>
> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItemsCustomerProfit(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update customer profit.',
    }
  }
}

const updateCostingFileItemStatus = async (
  payload: CostingFileItemStatusUpdateInput,
): Promise<CostingFileServiceResult<Pick<CostingFileItem, 'id' | 'status' | 'updated_at'>>> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItemStatus(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update item status.',
    }
  }
}

const updateCostingFileItemOffer = async (
  payload: CostingFileItemOfferUpdateInput,
): Promise<
  CostingFileServiceResult<
    Pick<CostingFileItem, 'id' | 'offer_price_override_bdt' | 'offer_price_bdt' | 'updated_at'>
  >
> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItemOffer(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update offer override.',
    }
  }
}

const updateCostingFileItem = async (
  payload: CostingFileItemUpdateInput,
): Promise<CostingFileServiceResult<CostingFileItem>> => {
  try {
    const data = await costingFileItemRepository.updateCostingFileItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update costing file item.',
    }
  }
}

const deleteCostingFileItem = async (
  payload: CostingFileItemDeleteInput,
): Promise<CostingFileServiceResult<CostingFileItemDeleteInput>> => {
  try {
    const data = await costingFileItemRepository.deleteCostingFileItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete costing file item.',
    }
  }
}

export const costingFileItemService = {
  listCostingFileItems,
  listCostingFileItemsForCustomer,
  createCostingFileItem,
  createCostingFileItemRequest,
  updateCostingFileItemEnrichment,
  updateCostingFileItemCustomerProfit,
  updateCostingFileItemsCustomerProfit,
  updateCostingFileItemStatus,
  updateCostingFileItemOffer,
  updateCostingFileItem,
  deleteCostingFileItem,
}
