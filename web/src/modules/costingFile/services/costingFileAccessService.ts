import { costingFileAccessRepository } from '../repositories/costingFileAccessRepository'
import type {
  CostingFileViewer,
  CostingFileViewerGrantInput,
  CostingFileViewerRevokeInput,
  TenantViewer,
} from '../types'

type AccessServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

const listTenantViewers = async (tenantId: number): Promise<AccessServiceResult<TenantViewer[]>> => {
  try {
    const data = await costingFileAccessRepository.listTenantViewers(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load tenant viewers.',
    }
  }
}

const listCostingFileViewers = async (
  costingFileId: number,
): Promise<AccessServiceResult<CostingFileViewer[]>> => {
  try {
    const data = await costingFileAccessRepository.listCostingFileViewers(costingFileId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load costing file viewers.',
    }
  }
}

const grantCostingFileViewer = async (
  payload: CostingFileViewerGrantInput,
): Promise<AccessServiceResult<CostingFileViewer>> => {
  try {
    const data = await costingFileAccessRepository.grantCostingFileViewer(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add viewer to costing file.',
    }
  }
}

const revokeCostingFileViewer = async (
  payload: CostingFileViewerRevokeInput,
): Promise<
  AccessServiceResult<Pick<CostingFileViewer, 'costing_file_viewer_id' | 'costing_file_id' | 'membership_id'>>
> => {
  try {
    const data = await costingFileAccessRepository.revokeCostingFileViewer(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to remove viewer from costing file.',
    }
  }
}

export const costingFileAccessService = {
  listTenantViewers,
  listCostingFileViewers,
  grantCostingFileViewer,
  revokeCostingFileViewer,
}

