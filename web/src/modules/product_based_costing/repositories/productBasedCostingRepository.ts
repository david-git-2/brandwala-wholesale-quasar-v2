import { supabase } from 'src/boot/supabase'

import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileDeleteInput,
  ProductBasedCostingFileUpdateInput,
} from '../types'

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null
  }

  const trimmed = value.trim()

  return trimmed.length > 0 ? trimmed : null
}

const buildPayload = (
  payload: ProductBasedCostingFileCreateInput | ProductBasedCostingFileUpdateInput,
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
    .insert([buildPayload(payload)])
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
    .update(buildPayload(rest))
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
  payload: ProductBasedCostingFileDeleteInput,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .delete()
    .eq('id', payload.id)
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

export const productBasedCostingRepository = {
  listProductBasedCostingFiles,
  createProductBasedCostingFile,
  updateProductBasedCostingFile,
  deleteProductBasedCostingFile,
}
