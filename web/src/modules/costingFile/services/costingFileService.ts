import { costingFileRepository } from '../repositories/costingFileRepository'
import { costingFileAccessService } from './costingFileAccessService'
import { costingFileItemService } from './costingFileItemService'
import type {
  CostingFileCreateInput,
  CostingFileDeleteInput,
  CostingFileDetails,
  CostingFileItem,
  CostingFileItemRequestCreateInput,
  CostingFileItemCustomerProfitUpdateInput,
  CostingFileItemEnrichmentUpdateInput,
  CostingFileItemOfferUpdateInput,
  CostingFileItemStatusUpdateInput,
  CostingFileListEntry,
  CostingFileListPageResult,
  CostingFilePricingUpdateInput,
  CostingFileViewer,
  CostingFileViewerGrantInput,
  CostingFileViewerRevokeInput,
  CostingFileServiceResult,
  CostingFileStatusUpdateInput,
  CostingFileUpdateInput,
  TenantViewer,
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

const listCostingFilesForTenantPage = async (
  tenantId: number,
  customerGroupId: number | null,
  page: number,
  pageSize: number,
): Promise<CostingFileServiceResult<CostingFileListPageResult>> => {
  try {
    const data = await costingFileRepository.listCostingFilesForTenantPage(
      tenantId,
      customerGroupId,
      page,
      pageSize,
    )

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
  tenantId?: number | null,
): Promise<CostingFileServiceResult<CostingFileListEntry[]>> => {
  try {
    const data = await costingFileRepository.listCostingFilesForCustomerGroup(
      customerGroupId,
      tenantId,
    )
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing files.',
    }
  }
}

const listCostingFilesForCustomerGroupPage = async (
  customerGroupId: number,
  tenantId: number | null | undefined,
  page: number,
  pageSize: number,
): Promise<CostingFileServiceResult<CostingFileListPageResult>> => {
  try {
    const data = await costingFileRepository.listCostingFilesForCustomerGroupPage(
      customerGroupId,
      tenantId,
      page,
      pageSize,
    )
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

const getCostingFileByIdForCustomer = async (
  id: number,
): Promise<CostingFileServiceResult<CostingFileDetails | null>> => {
  try {
    const data = await costingFileRepository.getCostingFileByIdForCustomer(id)
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

const listCostingFileItemsForCustomer = async (
  costingFileId: number,
): Promise<CostingFileServiceResult<CostingFileItem[]>> => {
  return costingFileItemService.listCostingFileItemsForCustomer(costingFileId)
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

const updateCostingFile = async (
  payload: CostingFileUpdateInput,
): Promise<CostingFileServiceResult<CostingFileDetails>> => {
  try {
    const data = await costingFileRepository.updateCostingFile(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update costing file.',
    }
  }
}

const deleteCostingFile = async (
  payload: CostingFileDeleteInput,
): Promise<CostingFileServiceResult<CostingFileDeleteInput>> => {
  try {
    const data = await costingFileRepository.deleteCostingFile(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete costing file.',
    }
  }
}

const createCostingFileItemRequest = async (
  payload: CostingFileItemRequestCreateInput,
): Promise<
  CostingFileServiceResult<
    Pick<
      CostingFileItem,
      | 'id'
      | 'costing_file_id'
      | 'item_type'
      | 'website_url'
      | 'quantity'
      | 'status'
      | 'created_by_email'
      | 'created_at'
      | 'updated_at'
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

const listTenantViewers = async (
  tenantId: number,
): Promise<CostingFileServiceResult<TenantViewer[]>> => {
  return costingFileAccessService.listTenantViewers(tenantId)
}

const listCostingFileViewers = async (
  costingFileId: number,
): Promise<CostingFileServiceResult<CostingFileViewer[]>> => {
  return costingFileAccessService.listCostingFileViewers(costingFileId)
}

const grantCostingFileViewer = async (
  payload: CostingFileViewerGrantInput,
): Promise<CostingFileServiceResult<CostingFileViewer>> => {
  return costingFileAccessService.grantCostingFileViewer(payload)
}

const revokeCostingFileViewer = async (
  payload: CostingFileViewerRevokeInput,
): Promise<
  CostingFileServiceResult<Pick<CostingFileViewer, 'costing_file_viewer_id' | 'costing_file_id' | 'membership_id'>>
> => {
  return costingFileAccessService.revokeCostingFileViewer(payload)
}

export const costingFileService = {
  listCostingFilesForTenant,
  listCostingFilesForTenantPage,
  listCostingFilesForCustomerGroup,
  listCostingFilesForCustomerGroupPage,
  getCostingFileById,
  getCostingFileByIdForCustomer,
  listCostingFileItems,
  listCostingFileItemsForCustomer,
  createCostingFile,
  updateCostingFile,
  deleteCostingFile,
  createCostingFileItemRequest,
  updateCostingFileStatus,
  updateCostingFilePricing,
  updateCostingFileItemEnrichment,
  updateCostingFileItemCustomerProfit,
  updateCostingFileItemStatus,
  updateCostingFileItemOffer,
  listTenantViewers,
  listCostingFileViewers,
  grantCostingFileViewer,
  revokeCostingFileViewer,
}
