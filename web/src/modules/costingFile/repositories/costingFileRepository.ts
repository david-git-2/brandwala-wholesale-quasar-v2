import { supabase } from 'src/boot/supabase'

import type {
  CostingFileCreateInput,
  CostingFileDeleteInput,
  CostingFileDetails,
  CostingFileListEntry,
  CostingFilePricingUpdateInput,
  CostingFileStatusUpdateInput,
  CostingFileUpdateInput,
} from '../types'

const listCostingFilesForTenant = async (tenantId: number): Promise<CostingFileListEntry[]> => {
  const { data, error } = await supabase.rpc('list_costing_files_for_actor', {
    p_tenant_id: tenantId,
    p_customer_group_id: null,
  })

  if (error) {
    throw error
  }

  return (data as CostingFileListEntry[] | null) ?? []
}

const listCostingFilesForCustomerGroup = async (
  customerGroupId: number,
  tenantId?: number | null,
): Promise<CostingFileListEntry[]> => {
  const { data, error } = await supabase.rpc('list_costing_files_for_actor', {
    p_tenant_id: tenantId ?? null,
    p_customer_group_id: customerGroupId,
  })

  if (error) {
    throw error
  }

  return (data as CostingFileListEntry[] | null) ?? []
}

const getCostingFileById = async (id: number): Promise<CostingFileDetails | null> => {
  const { data, error } = await supabase.rpc('get_costing_file_by_id', {
    p_id: id,
  })

  if (error) {
    throw error
  }

  const costingFile = Array.isArray(data) ? data[0] : data
  return (costingFile as CostingFileDetails | null) ?? null
}

const createCostingFile = async (payload: CostingFileCreateInput): Promise<CostingFileDetails> => {
  const { data, error } = await supabase.rpc('create_costing_file', {
    p_tenant_id: payload.tenantId,
    p_customer_group_id: payload.customerGroupId,
    p_name: payload.name,
    p_market: payload.market,
  })

  if (error) {
    throw error
  }

  const created = Array.isArray(data) ? data[0] : data

  if (!created) {
    throw new Error('Costing file was not created.')
  }

  return created as CostingFileDetails
}

const updateCostingFile = async (payload: CostingFileUpdateInput): Promise<CostingFileDetails> => {
  const { data, error } = await supabase.rpc('update_costing_file', {
    p_id: payload.id,
    p_name: payload.name ?? null,
    p_market: payload.market ?? null,
    p_customer_group_id: payload.customerGroupId ?? null,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Costing file was not updated.')
  }

  return updated as CostingFileDetails
}

const deleteCostingFile = async (payload: CostingFileDeleteInput): Promise<CostingFileDeleteInput> => {
  const { error } = await supabase.from('costing_files').delete().eq('id', payload.id)

  if (error) {
    throw error
  }

  return { id: payload.id }
}

const updateCostingFileStatus = async (
  payload: CostingFileStatusUpdateInput,
): Promise<Pick<CostingFileDetails, 'id' | 'status' | 'updated_at'>> => {
  const { data, error } = await supabase.rpc('update_costing_file_status', {
    p_id: payload.id,
    p_status: payload.status,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Costing file status was not updated.')
  }

  return updated as Pick<CostingFileDetails, 'id' | 'status' | 'updated_at'>
}

const updateCostingFilePricing = async (
  payload: CostingFilePricingUpdateInput,
): Promise<
  Pick<
    CostingFileDetails,
    'id' | 'cargo_rate_1kg' | 'cargo_rate_2kg' | 'conversion_rate' | 'admin_profit_rate' | 'updated_at'
  >
> => {
  const { data, error } = await supabase.rpc('update_costing_file_pricing', {
    p_id: payload.id,
    p_cargo_rate_1kg: payload.cargoRate1Kg ?? null,
    p_cargo_rate_2kg: payload.cargoRate2Kg ?? null,
    p_conversion_rate: payload.conversionRate ?? null,
    p_admin_profit_rate: payload.adminProfitRate ?? null,
  })

  if (error) {
    throw error
  }

  const updated = Array.isArray(data) ? data[0] : data

  if (!updated) {
    throw new Error('Costing file pricing was not updated.')
  }

  return updated as Pick<
    CostingFileDetails,
    'id' | 'cargo_rate_1kg' | 'cargo_rate_2kg' | 'conversion_rate' | 'admin_profit_rate' | 'updated_at'
  >
}

export const costingFileRepository = {
  listCostingFilesForTenant,
  listCostingFilesForCustomerGroup,
  getCostingFileById,
  createCostingFile,
  updateCostingFile,
  deleteCostingFile,
  updateCostingFileStatus,
  updateCostingFilePricing,
}
