import { supabase } from 'src/boot/supabase'

import type {
  CostingFile,
  CostingFileCreateInput,
  CostingFileDeleteInput,
  CostingFileDetails,
  CostingFileListEntry,
  CostingFileListPageResult,
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

const listCostingFilesForTenantPage = async (
  tenantId: number,
  customerGroupId: number | null,
  page: number,
  pageSize: number,
): Promise<CostingFileListPageResult> => {
  const safePage = Math.max(1, Math.floor(page || 1))
  const safePageSize = Math.max(1, Math.floor(pageSize || 20))
  const offset = (safePage - 1) * safePageSize

  const listResult = await supabase.rpc('list_costing_files_for_actor', {
    p_tenant_id: tenantId,
    p_customer_group_id: customerGroupId,
    p_limit: safePageSize,
    p_offset: offset,
  })

  if (listResult.error) {
    throw listResult.error
  }

  const rows =
    ((listResult.data as Array<CostingFileListEntry & { total_count?: number | null }> | null) ??
      [])

  return {
    items: rows.map((row) => ({
      id: row.id,
      name: row.name,
      market: row.market,
      status: row.status,
      customer_group_id: row.customer_group_id,
      tenant_id: row.tenant_id,
      created_by_email: row.created_by_email,
      created_at: row.created_at,
      updated_at: row.updated_at,
    })),
    total: Number(rows[0]?.total_count ?? 0),
  }
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

  return ((data as CostingFileListEntry[] | null) ?? []).map((item) => ({
    ...item,
    created_by_email: '',
  }))
}

const listCostingFilesForCustomerGroupPage = async (
  customerGroupId: number,
  tenantId: number | null | undefined,
  page: number,
  pageSize: number,
): Promise<CostingFileListPageResult> => {
  const safePage = Math.max(1, Math.floor(page || 1))
  const safePageSize = Math.max(1, Math.floor(pageSize || 20))
  const offset = (safePage - 1) * safePageSize

  const listResult = await supabase.rpc('list_costing_files_for_actor', {
    p_tenant_id: tenantId ?? null,
    p_customer_group_id: customerGroupId,
    p_limit: safePageSize,
    p_offset: offset,
  })

  if (listResult.error) {
    throw listResult.error
  }

  const rows =
    ((listResult.data as Array<CostingFileListEntry & { total_count?: number | null }> | null) ??
      [])

  return {
    items: rows.map((row) => ({
      id: row.id,
      name: row.name,
      market: row.market,
      status: row.status,
      customer_group_id: row.customer_group_id,
      tenant_id: row.tenant_id,
      created_by_email: '',
      created_at: row.created_at,
      updated_at: row.updated_at,
    })),
    total: Number(rows[0]?.total_count ?? 0),
  }
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

const getCostingFileByIdForCustomer = async (id: number): Promise<CostingFileDetails | null> => {
  const { data, error } = await supabase
    .from('costing_files')
    .select('id, name, market, status, customer_group_id, tenant_id, created_at, updated_at')
    .eq('id', id)
    .maybeSingle()

  if (error) {
    throw error
  }

  if (!data) {
    return null
  }

  const safe = data as Pick<
    CostingFile,
    'id' | 'name' | 'market' | 'status' | 'customer_group_id' | 'tenant_id' | 'created_at' | 'updated_at'
  >

  return {
    ...safe,
    cargo_rate_1kg: null,
    cargo_rate_2kg: null,
    conversion_rate: null,
    admin_profit_rate: null,
    created_by_email: '',
  }
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
  listCostingFilesForTenantPage,
  listCostingFilesForCustomerGroup,
  listCostingFilesForCustomerGroupPage,
  getCostingFileById,
  getCostingFileByIdForCustomer,
  createCostingFile,
  updateCostingFile,
  deleteCostingFile,
  updateCostingFileStatus,
  updateCostingFilePricing,
}
