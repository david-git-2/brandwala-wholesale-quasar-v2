import { supabase } from 'src/boot/supabase'

import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileListInput,
  ProductBasedCostingFileListPage,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemUpdateInput,
} from '../types'

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null
  }

  const trimmed = value.trim()

  return trimmed.length > 0 ? trimmed : null
}

const buildProductBasedCostingFileCreatePayload = (
  payload: ProductBasedCostingFileCreateInput,
) => ({
  tenant_id: payload.tenant_id ?? null,
  name: normalizeText(payload.name),
  order_for: normalizeText(payload.order_for),
  note: normalizeText(payload.note),
  cargo_rate_kg_gbp: payload.cargo_rate_kg_gbp ?? null,
  profit_rate: payload.profit_rate ?? null,
  conversion_rate: payload.conversion_rate ?? null,
  status: normalizeText(payload.status),
})

const buildProductBasedCostingFileUpdatePayload = (
  payload: Omit<ProductBasedCostingFileUpdateInput, 'id'>,
) => {
  const updatePayload: Record<string, unknown> = {}

  if (payload.tenant_id !== undefined) {
    updatePayload.tenant_id = payload.tenant_id
  }

  if (payload.name !== undefined) {
    updatePayload.name = normalizeText(payload.name)
  }

  if (payload.order_for !== undefined) {
    updatePayload.order_for = normalizeText(payload.order_for)
  }

  if (payload.note !== undefined) {
    updatePayload.note = normalizeText(payload.note)
  }

  if (payload.cargo_rate_kg_gbp !== undefined) {
    updatePayload.cargo_rate_kg_gbp = payload.cargo_rate_kg_gbp
  }

  if (payload.profit_rate !== undefined) {
    updatePayload.profit_rate = payload.profit_rate
  }

  if (payload.conversion_rate !== undefined) {
    updatePayload.conversion_rate = payload.conversion_rate
  }

  if (payload.status !== undefined) {
    updatePayload.status = normalizeText(payload.status)
  }

  return updatePayload
}

const buildProductBasedCostingItemCreatePayload = (
  payload: ProductBasedCostingItemCreateInput,
) => ({
  product_based_costing_file_id: payload.product_based_costing_file_id ?? null,
  name: normalizeText(payload.name),
  image_url: normalizeText(payload.image_url),
  note: normalizeText(payload.note),
  quantity: payload.quantity ?? null,
  barcode: normalizeText(payload.barcode),
  product_code: normalizeText(payload.product_code),
  vendor_code: normalizeText(payload.vendor_code),
  market_code: normalizeText(payload.market_code),
  web_link: normalizeText(payload.web_link),
  price_gbp: payload.price_gbp ?? null,
  product_weight: payload.product_weight ?? null,
  package_weight: payload.package_weight ?? null,
  offer_price: payload.offer_price ?? null,
  status: normalizeText(payload.status),
  product_id: payload.product_id,
  input_type: normalizeText(payload.input_type),
})

const buildProductBasedCostingItemUpdatePayload = (
  payload: Omit<ProductBasedCostingItemUpdateInput, 'id'>,
) => {
  const updatePayload: Record<string, unknown> = {}

  if (payload.product_based_costing_file_id !== undefined) {
    updatePayload.product_based_costing_file_id = payload.product_based_costing_file_id
  }

  if (payload.name !== undefined) {
    updatePayload.name = normalizeText(payload.name)
  }

  if (payload.image_url !== undefined) {
    updatePayload.image_url = normalizeText(payload.image_url)
  }

  if (payload.note !== undefined) {
    updatePayload.note = normalizeText(payload.note)
  }

  if (payload.quantity !== undefined) {
    updatePayload.quantity = payload.quantity
  }

  if (payload.barcode !== undefined) {
    updatePayload.barcode = normalizeText(payload.barcode)
  }

  if (payload.product_code !== undefined) {
    updatePayload.product_code = normalizeText(payload.product_code)
  }

  if (payload.vendor_code !== undefined) {
    updatePayload.vendor_code = normalizeText(payload.vendor_code)
  }

  if (payload.market_code !== undefined) {
    updatePayload.market_code = normalizeText(payload.market_code)
  }

  if (payload.web_link !== undefined) {
    updatePayload.web_link = normalizeText(payload.web_link)
  }

  if (payload.price_gbp !== undefined) {
    updatePayload.price_gbp = payload.price_gbp
  }

  if (payload.product_weight !== undefined) {
    updatePayload.product_weight = payload.product_weight
  }

  if (payload.package_weight !== undefined) {
    updatePayload.package_weight = payload.package_weight
  }

  if (payload.offer_price !== undefined) {
    updatePayload.offer_price = payload.offer_price
  }

  if (payload.status !== undefined) {
    updatePayload.status = normalizeText(payload.status)
  }

  if (payload.input_type !== undefined) {
    updatePayload.input_type = normalizeText(payload.input_type)
  }

  return updatePayload
}

const listProductBasedCostingFiles = async (
  payload: ProductBasedCostingFileListInput = {},
): Promise<ProductBasedCostingFileListPage> => {
  const page = Math.max(1, Number(payload.page ?? 1) || 1)
  const pageSize = Math.max(1, Number(payload.page_size ?? 20) || 20)
  const { data, error } = await supabase.rpc('list_product_based_costing_files', {
    p_page: page,
    p_page_size: pageSize,
    p_search: payload.search?.trim() || null,
    p_status: payload.status?.trim() || null,
    p_tenant_id: null,
  })

  if (error) {
    throw error
  }

  const envelope = (data as { data?: ProductBasedCostingFile[]; meta?: Record<string, unknown> } | null) ?? {}
  const rows = envelope.data ?? []
  const meta = envelope.meta ?? {}
  const total = Number(meta.total ?? rows.length ?? 0)
  const metaPage = Number(meta.page ?? page)
  const metaPageSize = Number(meta.page_size ?? pageSize)
  const metaTotalPages = Number(meta.total_pages ?? Math.max(1, Math.ceil(total / pageSize)))

  return {
    data: rows,
    meta: {
      total,
      page: Number.isFinite(metaPage) && metaPage > 0 ? metaPage : page,
      page_size: Number.isFinite(metaPageSize) && metaPageSize > 0 ? metaPageSize : pageSize,
      total_pages: Number.isFinite(metaTotalPages) && metaTotalPages > 0
        ? metaTotalPages
        : Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const createProductBasedCostingFile = async (
  payload: ProductBasedCostingFileCreateInput,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .insert([buildProductBasedCostingFileCreatePayload(payload)])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing file was not created.')
  }

  return data as ProductBasedCostingFile
}

const updateProductBasedCostingFile = async (
  payload: ProductBasedCostingFileUpdateInput,
): Promise<ProductBasedCostingFile> => {
  const { id, ...rest } = payload

  const { data, error } = await supabase
    .from('product_based_costing_files')
    .update(buildProductBasedCostingFileUpdatePayload(rest))
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing file was not updated.')
  }

  return data as ProductBasedCostingFile
}

const deleteProductBasedCostingFile = async (
  id: number,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .delete()
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing file was not deleted.')
  }

  return data as ProductBasedCostingFile
}

const getProductBasedCostingFileById = async (
  id: number,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing file not found.')
  }

  return data as ProductBasedCostingFile
}

const listProductBasedCostingItems = async (
  productBasedCostingFileId: number,
): Promise<ProductBasedCostingItem[]> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .select('*')
    .eq('product_based_costing_file_id', productBasedCostingFileId)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as ProductBasedCostingItem[] | null) ?? []
}

const createProductBasedCostingItem = async (
  payload: ProductBasedCostingItemCreateInput,
): Promise<ProductBasedCostingItem> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .insert([buildProductBasedCostingItemCreatePayload(payload)])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing item was not created.')
  }

  return data as ProductBasedCostingItem
}

const updateProductBasedCostingItem = async (
  payload: ProductBasedCostingItemUpdateInput,
): Promise<ProductBasedCostingItem> => {
  const { id, ...rest } = payload

  const { data, error } = await supabase
    .from('product_based_costing_items')
    .update(buildProductBasedCostingItemUpdatePayload(rest))
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing item was not updated.')
  }

  return data as ProductBasedCostingItem
}

const deleteProductBasedCostingItem = async (
  id: number,
): Promise<ProductBasedCostingItem> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .delete()
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing item was not deleted.')
  }

  return data as ProductBasedCostingItem
}

const getProductBasedCostingItemById = async (
  id: number,
): Promise<ProductBasedCostingItem> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product based costing item not found.')
  }

  return data as ProductBasedCostingItem
}

export const productBasedCostingRepository = {
  listProductBasedCostingFiles,
  createProductBasedCostingFile,
  updateProductBasedCostingFile,
  deleteProductBasedCostingFile,
  getProductBasedCostingFileById,

  listProductBasedCostingItems,
  createProductBasedCostingItem,
  updateProductBasedCostingItem,
  deleteProductBasedCostingItem,
  getProductBasedCostingItemById,
}
