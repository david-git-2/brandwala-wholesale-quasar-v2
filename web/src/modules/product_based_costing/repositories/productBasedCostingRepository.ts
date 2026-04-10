import { supabase } from 'src/boot/supabase'

import type {
  ProductBasedCostingFile,
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

const buildProductBasedCostingFilePayload = (
  payload:
    | ProductBasedCostingFileCreateInput
    | Omit<ProductBasedCostingFileUpdateInput, 'id'>,
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

const buildProductBasedCostingItemPayload = (
  payload:
    | ProductBasedCostingItemCreateInput
    | Omit<ProductBasedCostingItemUpdateInput, 'id'>,
) => ({
  product_based_costing_file_id: payload.product_based_costing_file_id ?? null,
  name: normalizeText(payload.name),
  image_url: normalizeText(payload.image_url),
  quantity: payload.quantity ?? null,
  barcode: normalizeText(payload.barcode),
  product_code: normalizeText(payload.product_code),
  web_link: normalizeText(payload.web_link),
  price_gbp: payload.price_gbp ?? null,
  product_weight: payload.product_weight ?? null,
  package_weight: payload.package_weight ?? null,
  offer_price: payload.offer_price ?? null,
  status: normalizeText(payload.status),
})

const listProductBasedCostingFiles = async (): Promise<ProductBasedCostingFile[]> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as ProductBasedCostingFile[] | null) ?? []
}

const createProductBasedCostingFile = async (
  payload: ProductBasedCostingFileCreateInput,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .insert([buildProductBasedCostingFilePayload(payload)])
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
    .update(buildProductBasedCostingFilePayload(rest))
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

/**
 * item list api
 * takes productBasedCostingFileId as argument
 * returns item list only for that file id
 */
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
    .insert([buildProductBasedCostingItemPayload(payload)])
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
    .update(buildProductBasedCostingItemPayload(rest))
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
