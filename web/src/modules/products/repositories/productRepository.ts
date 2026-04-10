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

const buildProductPayload = (payload: ProductCreateInput) => ({
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

const buildProductUpdatePayload = (payload: Omit<ProductUpdateInput, 'id'>) => {
  const updateData: Record<string, unknown> = {}

  if ('tenant_id' in payload) {
    updateData.tenant_id = payload.tenant_id ?? null
  }

  if ('product_code' in payload) {
    updateData.product_code = normalizeText(payload.product_code)
  }

  if ('barcode' in payload) {
    updateData.barcode = normalizeText(payload.barcode)
  }

  if ('name' in payload) {
    updateData.name = normalizeText(payload.name)
  }

  if ('price_gbp' in payload) {
    updateData.price_gbp = payload.price_gbp ?? null
  }

  if ('country_of_origin' in payload) {
    updateData.country_of_origin = normalizeText(payload.country_of_origin)
  }

  if ('brand' in payload) {
    updateData.brand = normalizeText(payload.brand)
  }

  if ('category' in payload) {
    updateData.category = normalizeText(payload.category)
  }

  if ('available_units' in payload) {
    updateData.available_units = payload.available_units ?? null
  }

  if ('tariff_code' in payload) {
    updateData.tariff_code = normalizeText(payload.tariff_code)
  }

  if ('languages' in payload) {
    updateData.languages = normalizeText(payload.languages)
  }

  if ('batch_code_manufacture_date' in payload) {
    updateData.batch_code_manufacture_date = payload.batch_code_manufacture_date ?? null
  }

  if ('image_url' in payload) {
    updateData.image_url = normalizeText(payload.image_url)
  }

  if ('expire_date' in payload) {
    updateData.expire_date = payload.expire_date ?? null
  }

  if ('minimum_order_quantity' in payload) {
    updateData.minimum_order_quantity = payload.minimum_order_quantity ?? null
  }

  if ('product_weight' in payload) {
    updateData.product_weight = payload.product_weight ?? null
  }

  if ('package_weight' in payload) {
    updateData.package_weight = payload.package_weight ?? null
  }

  if ('vendor_code' in payload) {
    updateData.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null
  }

  if ('market_code' in payload) {
    updateData.market_code = normalizeText(payload.market_code)?.toUpperCase() ?? null
  }

  if ('is_available' in payload) {
    updateData.is_available = payload.is_available ?? null
  }

  return updateData
}

type PaginatedProducts = {
  data: Product[]
  total: number
  page: number
  pageSize: number
}

type ListProductsParams = {
  page?: number
  pageSize?: number
  search?: string
  category?: string | null | undefined
  brand?: string | null | undefined
  sortPrice?: 'asc' | 'desc'
  tenantId?: number | null | undefined
  vendorCode?: string | null | undefined
}

const listBrands = async (): Promise<string[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('brand')
    .order('brand', { ascending: true })

  if (error) {
    throw error
  }

  const seen = new Set<string>()
  const rows = (data as Array<{ brand: string | null }> | null) ?? []

  return rows
    .map((row) => row.brand?.trim() ?? '')
    .filter((brand) => brand.length > 0)
    .filter((brand) => {
      const key = brand.toLowerCase()

      if (seen.has(key)) {
        return false
      }

      seen.add(key)
      return true
    })
}

const listCategories = async (): Promise<string[]> => {
  const { data, error } = await supabase
    .from('products')
    .select('category')
    .order('category', { ascending: true })

  if (error) {
    throw error
  }

  const seen = new Set<string>()
  const rows = (data as Array<{ category: string | null }> | null) ?? []

  return rows
    .map((row) => row.category?.trim() ?? '')
    .filter((category) => category.length > 0)
    .filter((category) => {
      const key = category.toLowerCase()

      if (seen.has(key)) {
        return false
      }

      seen.add(key)
      return true
    })
}
const listProducts = async ({
  page = 1,
  pageSize = 20,
  search = '',
  category,
  brand,
  tenantId,
  vendorCode,
}: ListProductsParams): Promise<PaginatedProducts> => {
  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  let query = supabase
    .from('products')
    .select('*', { count: 'exact' })

  if (tenantId != null) {
    query = query.eq('tenant_id', tenantId)
  }

  if (vendorCode) {
    query = query.eq('vendor_code', vendorCode)
  }

  if (search.trim()) {
    query = query.or(
      `name.ilike.%${search}%,product_code.ilike.%${search}%,barcode.ilike.%${search}%`
    )
  }

  if (category) {
    query = query.eq('category', category)
  }

  if (brand) {
    query = query.eq('brand', brand)
  }

  query = query
    .order('name', { ascending: true })
    .range(from, to)

  const { data, error, count } = await query

  if (error) {
    throw error
  }

  return {
    data: (data as Product[] | null) ?? [],
    total: count ?? 0,
    page,
    pageSize,
  }
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

  const updatePayload = buildProductUpdatePayload(rest)

  const { data, error } = await supabase
    .from('products')
    .update(updatePayload)
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
  listBrands,
  listCategories,
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
}
