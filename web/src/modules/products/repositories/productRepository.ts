import { supabase } from 'src/boot/supabase'

import type {
  ProductBrand,
  ProductBrandCreateInput,
  ProductBrandDeleteInput,
  ProductBrandUpdateInput,
  ProductCategory,
  ProductCategoryCreateInput,
  ProductCategoryDeleteInput,
  ProductCategoryUpdateInput,
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductListPage,
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
  list_price_amount: payload.list_price_amount ?? null,
  list_price_currency_id: payload.list_price_currency_id ?? null,
  reference_cost_amount: payload.reference_cost_amount ?? null,
  reference_cost_currency_id: payload.reference_cost_currency_id ?? null,
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

  if ('list_price_amount' in payload) {
    updateData.list_price_amount = payload.list_price_amount ?? null
  }

  if ('list_price_currency_id' in payload) {
    updateData.list_price_currency_id = payload.list_price_currency_id ?? null
  }

  if ('reference_cost_amount' in payload) {
    updateData.reference_cost_amount = payload.reference_cost_amount ?? null
  }

  if ('reference_cost_currency_id' in payload) {
    updateData.reference_cost_currency_id = payload.reference_cost_currency_id ?? null
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

type ListProductsParams = {
  page?: number
  pageSize?: number
  search?: string | null | undefined
  searchField?: 'name' | 'barcode' | 'product_code' | 'id'
  category?: string | null | undefined
  brand?: string | null | undefined
  sortPrice?: 'asc' | 'desc'
  tenantId?: number | null | undefined
  vendorCode?: string | null | undefined
  marketCode?: string | null | undefined
  isAvailable?: boolean | null | undefined
}

type ListProductLookupParams = {
  vendorCode?: string | null | undefined
  vendorId?: number | null | undefined
  tenantId?: number | null | undefined
}

let isListProductsPaginatedRpcAvailable = true

const buildEmptyProductPage = (page: number, pageSize: number): ProductListPage => ({
  data: [],
  meta: {
    total: 0,
    page,
    page_size: pageSize,
    total_pages: 1,
  },
})

const isMissingListProductsRpcError = (error: { code?: string; message?: string } | null) =>
  error?.code === 'PGRST202' && (error.message ?? '').includes('list_products_paginated')

const listProductsFallback = async ({
  page = 1,
  pageSize = 20,
  search = '',
  searchField = 'name',
  category,
  brand,
  tenantId,
  vendorCode,
  marketCode,
  isAvailable,
  sortPrice,
}: ListProductsParams): Promise<ProductListPage> => {
  const offset = (page - 1) * pageSize
  const normalizedSearch = normalizeText(search)
  const normalizedCategory = normalizeText(category ?? null)
  const normalizedBrand = normalizeText(brand ?? null)
  const normalizedVendorCode = normalizeText(vendorCode ?? null)?.toUpperCase() ?? null
  const normalizedMarketCode = normalizeText(marketCode ?? null)?.toUpperCase() ?? null

  let query = supabase.from('products').select('*', { count: 'exact' })

  if (tenantId !== null && tenantId !== undefined) {
    query = query.or(`tenant_id.eq.${tenantId},parent_tenant_id.eq.${tenantId}`)
  }

  if (normalizedCategory) {
    query = query.ilike('category', normalizedCategory)
  }

  if (normalizedBrand) {
    query = query.ilike('brand', normalizedBrand)
  }

  if (normalizedVendorCode) {
    query = query.ilike('vendor_code', normalizedVendorCode)
  }

  if (normalizedMarketCode) {
    query = query.ilike('market_code', normalizedMarketCode)
  }

  if (typeof isAvailable === 'boolean') {
    query = query.eq('is_available', isAvailable)
  }

  if (normalizedSearch) {
    if (searchField === 'id') {
      const maybeId = Number(normalizedSearch)
      if (!Number.isNaN(maybeId) && Number.isFinite(maybeId)) {
        query = query.eq('id', maybeId)
      } else {
        return buildEmptyProductPage(page, pageSize)
      }
    } else {
      query = query.ilike(searchField, `%${normalizedSearch}%`)
    }
  }

  const { data, error, count } = await query
    .order('name', { ascending: sortPrice !== 'desc', nullsFirst: false })
    .order('id', { ascending: true })
    .range(offset, offset + pageSize - 1)

  if (error) {
    throw error
  }

  const total = count ?? 0

  return {
    data: (data as Product[] | null) ?? [],
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: Math.max(1, Math.ceil(total / pageSize)),
    },
  }
}

const listBrands = async ({ vendorCode, tenantId }: ListProductLookupParams = {}): Promise<string[]> => {
  if (typeof tenantId !== 'number') {
    return []
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null
  const { data, error } = await supabase.rpc('list_product_brands_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: null,
  })

  if (error) {
    throw error
  }

  return ((data as Array<{ name: string | null }> | null) ?? [])
    .map((row) => row.name?.trim() ?? '')
    .filter((brand) => brand.length > 0)
}

const listCategories = async ({ vendorCode, tenantId }: ListProductLookupParams = {}): Promise<string[]> => {
  if (typeof tenantId !== 'number') {
    return []
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null
  const { data, error } = await supabase.rpc('list_product_categories_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: null,
  })

  if (error) {
    throw error
  }

  return ((data as Array<{ name: string | null }> | null) ?? [])
    .map((row) => row.name?.trim() ?? '')
    .filter((category) => category.length > 0)
}
const listProducts = async ({
  page = 1,
  pageSize = 20,
  search = '',
  searchField = 'name',
  category,
  brand,
  tenantId,
  vendorCode,
  marketCode,
  isAvailable,
  sortPrice,
}: ListProductsParams): Promise<ProductListPage> => {
  if (!isListProductsPaginatedRpcAvailable) {
    const fallbackParams: ListProductsParams = {
      page,
      pageSize,
      search,
      searchField,
      category,
      brand,
      tenantId,
      vendorCode,
      marketCode,
      isAvailable,
    }

    if (sortPrice) {
      fallbackParams.sortPrice = sortPrice
    }

    return listProductsFallback({
      ...fallbackParams,
    })
  }

  const offset = (page - 1) * pageSize
  const { data, error } = await supabase.rpc('list_products_paginated' as never, {
    p_tenant_id: tenantId ?? null,
    p_search: search ?? null,
    p_search_field: searchField ?? 'name',
    p_category: category ?? null,
    p_brand: brand ?? null,
    p_vendor_code: vendorCode ?? null,
    p_market_code: marketCode ?? null,
    p_is_available: typeof isAvailable === 'boolean' ? isAvailable : null,
    p_sort_by: 'name',
    p_sort_dir: sortPrice ?? 'asc',
    p_limit: pageSize,
    p_offset: offset,
  } as never)

  if (error) {
    if (isMissingListProductsRpcError(error)) {
      isListProductsPaginatedRpcAvailable = false

      const fallbackParams: ListProductsParams = {
        page,
        pageSize,
        search,
        searchField,
        category,
        brand,
        tenantId,
      vendorCode,
      marketCode,
      isAvailable,
    }

      if (sortPrice) {
        fallbackParams.sortPrice = sortPrice
      }

      return listProductsFallback({
        ...fallbackParams,
      })
    }
    throw error
  }

  const response = (data as ProductListPage | null) ?? null
  if (!response) {
    return buildEmptyProductPage(page, pageSize)
  }

  return {
    data: response.data ?? [],
    meta: {
      total: response.meta?.total ?? 0,
      page: response.meta?.page ?? page,
      page_size: response.meta?.page_size ?? pageSize,
      total_pages: response.meta?.total_pages ?? 1,
    },
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

const getProductById = async (id: number, tenantId?: number | null): Promise<Product> => {
  if (typeof tenantId === 'number') {
    const { data, error } = await supabase.rpc('get_product_for_tenant', {
      p_id: id,
      p_tenant_id: tenantId,
    })

    if (error) {
      throw error
    }

    if (!data) {
      throw new Error('Product not found.')
    }

    return data as Product
  }

  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    throw error
  }

  if (!data) {
    throw new Error('Product not found.')
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

const listProductBrands = async ({
  vendorCode,
  vendorId,
  tenantId,
}: ListProductLookupParams = {}): Promise<ProductBrand[]> => {
  if (typeof tenantId !== 'number') {
    return []
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null
  const { data, error } = await supabase.rpc('list_product_brands_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: typeof vendorId === 'number' ? vendorId : null,
  })

  if (error) throw error

  return (data as ProductBrand[] | null) ?? []
}

const createProductBrand = async (payload: ProductBrandCreateInput): Promise<ProductBrand> => {
  const name = normalizeText(payload.name)?.toUpperCase() ?? ''
  if (!name) throw new Error('Brand name is required.')
  const vendorCode = normalizeText(payload.vendor_code)?.toUpperCase() ?? null

  const insertData: ProductBrandCreateInput = {
    name,
    vendor_code: vendorCode,
    vendor_id: payload.vendor_id ?? null,
    tenant_id: payload.tenant_id ?? null,
  }

  const { data, error } = await supabase
    .from('product_brands')
    .insert([insertData])
    .select('*')
    .single()

  if (error) throw error
  if (!data) throw new Error('Brand was not created.')
  return data as ProductBrand
}

const updateProductBrand = async (payload: ProductBrandUpdateInput): Promise<ProductBrand> => {
  const patch: ProductBrandUpdateInput = { id: payload.id }
  if (payload.name !== undefined) patch.name = normalizeText(payload.name)?.toUpperCase() ?? ''
  if (payload.vendor_code !== undefined) patch.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null
  if (payload.vendor_id !== undefined) patch.vendor_id = payload.vendor_id
  if (payload.tenant_id !== undefined) patch.tenant_id = payload.tenant_id

  const { data, error } = await supabase
    .from('product_brands')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) throw error
  if (!data) throw new Error('Brand was not updated.')
  return data as ProductBrand
}

const deleteProductBrand = async (payload: ProductBrandDeleteInput): Promise<void> => {
  const { error } = await supabase.from('product_brands').delete().eq('id', payload.id)
  if (error) throw error
}

const listProductCategories = async ({
  vendorCode,
  vendorId,
  tenantId,
}: ListProductLookupParams = {}): Promise<ProductCategory[]> => {
  if (typeof tenantId !== 'number') {
    return []
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null
  const { data, error } = await supabase.rpc('list_product_categories_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: typeof vendorId === 'number' ? vendorId : null,
  })

  if (error) throw error

  return (data as ProductCategory[] | null) ?? []
}

const createProductCategory = async (payload: ProductCategoryCreateInput): Promise<ProductCategory> => {
  const name = normalizeText(payload.name) ?? ''
  if (!name) throw new Error('Category name is required.')
  const vendorCode = normalizeText(payload.vendor_code)?.toUpperCase() ?? null

  const insertData: ProductCategoryCreateInput = {
    name,
    vendor_code: vendorCode,
    vendor_id: payload.vendor_id ?? null,
    tenant_id: payload.tenant_id ?? null,
  }

  const { data, error } = await supabase
    .from('product_categories')
    .insert([insertData])
    .select('*')
    .single()

  if (error) throw error
  if (!data) throw new Error('Category was not created.')
  return data as ProductCategory
}

const updateProductCategory = async (payload: ProductCategoryUpdateInput): Promise<ProductCategory> => {
  const patch: ProductCategoryUpdateInput = { id: payload.id }
  if (payload.name !== undefined) patch.name = normalizeText(payload.name) ?? ''
  if (payload.vendor_code !== undefined) patch.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null
  if (payload.vendor_id !== undefined) patch.vendor_id = payload.vendor_id
  if (payload.tenant_id !== undefined) patch.tenant_id = payload.tenant_id

  const { data, error } = await supabase
    .from('product_categories')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single()

  if (error) throw error
  if (!data) throw new Error('Category was not updated.')
  return data as ProductCategory
}

const deleteProductCategory = async (payload: ProductCategoryDeleteInput): Promise<void> => {
  const { error } = await supabase.from('product_categories').delete().eq('id', payload.id)
  if (error) throw error
}

export const productRepository = {
  listBrands,
  listCategories,
  listProductBrands,
  createProductBrand,
  updateProductBrand,
  deleteProductBrand,
  listProductCategories,
  createProductCategory,
  updateProductCategory,
  deleteProductCategory,
  listProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
}
