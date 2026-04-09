import { supabase } from 'src/boot/supabase'

import type {
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductUpdateInput,
} from '../types'

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null
  }

  const trimmed = value.trim()

  return trimmed.length > 0 ? trimmed : null
}

const buildProductPayload = (payload: ProductCreateInput | ProductUpdateInput) => ({
  tenant_id: payload.tenant_id ?? null,
  product_code: normalizeText(payload.product_code),
  barcode: normalizeText(payload.barcode),
  name: normalizeText(payload.name),
  price_gbp: payload.price_gbp ?? null,
  country_of_origin: normalizeText(payload.country_of_origin),
  brand: normalizeText(payload.brand),
  category: normalizeText(payload.category),
  available_units: payload.available_units ?? null,
  tariff_code: normalizeText(payload.tariff_code),
  languages: normalizeText(payload.languages),
  batch_code_manufacture_date: payload.batch_code_manufacture_date ?? null,
  image_url: normalizeText(payload.image_url),
  expire_date: payload.expire_date ?? null,
  minimum_order_quantity: payload.minimum_order_quantity ?? null,
  product_weight: payload.product_weight ?? null,
  package_weight: payload.package_weight ?? null,
  vendor_code: normalizeText(payload.vendor_code)?.toUpperCase() ?? null,
  market_code: normalizeText(payload.market_code)?.toUpperCase() ?? null,
  is_available: payload.is_available ?? null,
})

const listProducts = async (): Promise<Product[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as Product[] | null) ?? []
}

const createProduct = async (payload: ProductCreateInput): Promise<Product> => {
  const { data, error } = await supabase
    .from('products')
    .insert([buildProductPayload(payload)])
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product was not created.')
  }

  return data as Product
}

const updateProduct = async (payload: ProductUpdateInput): Promise<Product> => {
  const { id, ...rest } = payload

  const { data, error } = await supabase
    .from('products')
    .update(buildProductPayload(rest))
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product was not updated.')
  }

  return data as Product
}

const deleteProduct = async (payload: ProductDeleteInput): Promise<Product> => {
  const { data, error } = await supabase
    .from('products')
    .delete()
    .eq('id', payload.id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product was not deleted.')
  }

  return data as Product
}

export const productRepository = {
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
}
