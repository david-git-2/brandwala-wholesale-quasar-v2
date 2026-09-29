import { supabase } from 'src/boot/supabase';

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
  ProductListCursor,
  ProductListPage,
  ProductUpdateInput,
} from '../types';

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null;
  }

  const trimmed = value.trim();

  return trimmed.length > 0 ? trimmed : null;
};

const applyProductInsertScope = async (
  payload: ProductCreateInput,
  resolvedParentByTenant: Map<number, number>,
): Promise<ProductCreateInput> => {
  const insertedBy = payload.inserted_by_tenant_id ?? null;
  let parentTenantId = payload.parent_tenant_id ?? null;

  if (parentTenantId == null && insertedBy != null) {
    let cached = resolvedParentByTenant.get(insertedBy);
    if (cached === undefined) {
      cached = await resolveProductScopeTenantId(insertedBy);
      resolvedParentByTenant.set(insertedBy, cached);
    }
    parentTenantId = cached;
  }

  return {
    ...payload,
    parent_tenant_id: parentTenantId,
    inserted_by_tenant_id: insertedBy,
  };
};

const buildProductPayload = (payload: ProductCreateInput) => ({
  parent_tenant_id: payload.parent_tenant_id ?? null,
  inserted_by_tenant_id: payload.inserted_by_tenant_id ?? null,
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
});

const buildProductUpdatePayload = (payload: Omit<ProductUpdateInput, 'id'>) => {
  const updateData: Record<string, unknown> = {};

  if ('parent_tenant_id' in payload) {
    updateData.parent_tenant_id = payload.parent_tenant_id ?? null;
  }

  if ('inserted_by_tenant_id' in payload) {
    updateData.inserted_by_tenant_id = payload.inserted_by_tenant_id ?? null;
  }

  if ('product_code' in payload) {
    updateData.product_code = normalizeText(payload.product_code);
  }

  if ('barcode' in payload) {
    updateData.barcode = normalizeText(payload.barcode);
  }

  if ('name' in payload) {
    updateData.name = normalizeText(payload.name);
  }

  if ('list_price_amount' in payload) {
    updateData.list_price_amount = payload.list_price_amount ?? null;
  }

  if ('list_price_currency_id' in payload) {
    updateData.list_price_currency_id = payload.list_price_currency_id ?? null;
  }

  if ('reference_cost_amount' in payload) {
    updateData.reference_cost_amount = payload.reference_cost_amount ?? null;
  }

  if ('reference_cost_currency_id' in payload) {
    updateData.reference_cost_currency_id = payload.reference_cost_currency_id ?? null;
  }

  if ('country_of_origin' in payload) {
    updateData.country_of_origin = normalizeText(payload.country_of_origin);
  }

  if ('brand' in payload) {
    updateData.brand = normalizeText(payload.brand);
  }

  if ('category' in payload) {
    updateData.category = normalizeText(payload.category);
  }

  if ('available_units' in payload) {
    updateData.available_units = payload.available_units ?? null;
  }

  if ('languages' in payload) {
    updateData.languages = normalizeText(payload.languages);
  }

  if ('batch_code_manufacture_date' in payload) {
    updateData.batch_code_manufacture_date = payload.batch_code_manufacture_date ?? null;
  }

  if ('image_url' in payload) {
    updateData.image_url = normalizeText(payload.image_url);
  }

  if ('expire_date' in payload) {
    updateData.expire_date = payload.expire_date ?? null;
  }

  if ('minimum_order_quantity' in payload) {
    updateData.minimum_order_quantity = payload.minimum_order_quantity ?? null;
  }

  if ('product_weight' in payload) {
    updateData.product_weight = payload.product_weight ?? null;
  }

  if ('package_weight' in payload) {
    updateData.package_weight = payload.package_weight ?? null;
  }

  if ('vendor_code' in payload) {
    updateData.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null;
  }

  if ('market_code' in payload) {
    updateData.market_code = normalizeText(payload.market_code)?.toUpperCase() ?? null;
  }

  if ('is_available' in payload) {
    updateData.is_available = payload.is_available ?? null;
  }

  return updateData;
};

export type ListProductsParams = {
  pageSize?: number;
  cursor?: ProductListCursor | null;
  search?: string | null | undefined;
  searchField?: 'name' | 'barcode' | 'product_code' | 'id';
  category?: string | null | undefined;
  brand?: string | null | undefined;
  sortPrice?: 'asc' | 'desc';
  tenantId?: number | null | undefined;
  vendorCode?: string | null | undefined;
  marketCode?: string | null | undefined;
  isAvailable?: boolean | null | undefined;
};

type ListProductLookupParams = {
  vendorCode?: string | null | undefined;
  vendorId?: number | null | undefined;
  tenantId?: number | null | undefined;
};

let isListProductsPaginatedRpcAvailable = true;

const buildEmptyProductPage = (pageSize: number): ProductListPage => ({
  data: [],
  meta: {
    has_more: false,
    next_cursor: null,
    limit: pageSize,
  },
});

const parseProductListCursor = (raw: unknown): ProductListCursor | null => {
  if (!raw || typeof raw !== 'object') return null;
  const cursor = raw as { name?: unknown; id?: unknown };
  const id = Number(cursor.id);
  if (!Number.isFinite(id)) return null;
  const name = typeof cursor.name === 'string' ? cursor.name : '';
  return { name, id };
};

const isMissingListProductsRpcError = (error: any): boolean => {
  if (!error) return false;
  const msg = String(error.message || '').toLowerCase();
  return (
    error.code === 'PGRST202' ||
    msg.includes('function public.list_products_paginated') ||
    msg.includes('could not find the function')
  );
};

const parentTenantIdCache = new Map<number, number>();

const resolveProductScopeTenantId = async (tenantId: number): Promise<number> => {
  if (parentTenantIdCache.has(tenantId)) {
    return parentTenantIdCache.get(tenantId)!;
  }

  const { data, error } = await supabase.rpc('resolve_parent_tenant_id', {
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }

  const resolved = data as number;
  parentTenantIdCache.set(tenantId, resolved);
  return resolved;
};

const applyKeysetCursorFilter = (
  query: ReturnType<typeof supabase.from>,
  cursor: ProductListCursor,
  ascending: boolean,
) => {
  const cursorName = cursor.name.replace(/"/g, '\\"');
  const op = ascending ? 'gt' : 'lt';
  const idOp = ascending ? 'gt' : 'lt';
  return query.or(
    `name.${op}."${cursorName}",and(name.eq."${cursorName}",id.${idOp}.${cursor.id})`,
  );
};

const listProductsFallback = async ({
  pageSize = 20,
  cursor = null,
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
  const limit = Math.max(1, pageSize);
  const ascending = sortPrice !== 'desc';
  const normalizedSearch = normalizeText(search);
  const normalizedCategory = normalizeText(category ?? null);
  const normalizedBrand = normalizeText(brand ?? null);
  const normalizedVendorCode = normalizeText(vendorCode ?? null)?.toUpperCase() ?? null;
  const normalizedMarketCode = normalizeText(marketCode ?? null)?.toUpperCase() ?? null;

  let query = supabase.from('products').select('*');

  if (tenantId !== null && tenantId !== undefined) {
    const scopeTenantId = await resolveProductScopeTenantId(tenantId);
    query = query.eq('parent_tenant_id', scopeTenantId);
  }

  if (normalizedCategory) {
    query = query.ilike('category', normalizedCategory);
  }

  if (normalizedBrand) {
    query = query.ilike('brand', normalizedBrand);
  }

  if (normalizedVendorCode) {
    query = query.ilike('vendor_code', normalizedVendorCode);
  }

  if (normalizedMarketCode) {
    query = query.ilike('market_code', normalizedMarketCode);
  }

  if (typeof isAvailable === 'boolean') {
    query = query.eq('is_available', isAvailable);
  }

  if (normalizedSearch) {
    if (searchField === 'id') {
      const maybeId = Number(normalizedSearch);
      if (!Number.isNaN(maybeId) && Number.isFinite(maybeId)) {
        query = query.eq('id', maybeId);
      } else {
        return buildEmptyProductPage(limit);
      }
    } else {
      query = query.ilike(searchField, `%${normalizedSearch}%`);
    }
  }

  if (cursor) {
    query = applyKeysetCursorFilter(query, cursor, ascending);
  }

  const { data, error } = await query
    .order('name', { ascending, nullsFirst: false })
    .order('id', { ascending })
    .limit(limit + 1);

  if (error) {
    throw error;
  }

  const rows = (data as Product[] | null) ?? [];
  const hasMore = rows.length > limit;
  const pageRows = hasMore ? rows.slice(0, limit) : rows;
  const last = pageRows[pageRows.length - 1];

  return {
    data: pageRows,
    meta: {
      has_more: hasMore,
      next_cursor:
        hasMore && last
          ? { name: last.name ?? '', id: last.id }
          : null,
      limit,
    },
  };
};

const listBrands = async ({ vendorCode, tenantId }: ListProductLookupParams = {}): Promise<
  string[]
> => {
  if (typeof tenantId !== 'number') {
    return [];
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null;
  const { data, error } = await supabase.rpc('list_product_brands_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: null,
  });

  if (error) {
    throw error;
  }

  return ((data as Array<{ name: string | null }> | null) ?? [])
    .map((row) => row.name?.trim() ?? '')
    .filter((brand) => brand.length > 0);
};

const listCategories = async ({ vendorCode, tenantId }: ListProductLookupParams = {}): Promise<
  string[]
> => {
  if (typeof tenantId !== 'number') {
    return [];
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null;
  const { data, error } = await supabase.rpc('list_product_categories_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: null,
  });

  if (error) {
    throw error;
  }

  return ((data as Array<{ name: string | null }> | null) ?? [])
    .map((row) => row.name?.trim() ?? '')
    .filter((category) => category.length > 0);
};
const listProducts = async ({
  pageSize = 20,
  cursor = null,
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
  const limit = Math.max(1, pageSize);

  const runFallback = () =>
    listProductsFallback({
      pageSize: limit,
      cursor,
      search,
      searchField,
      category,
      brand,
      tenantId,
      vendorCode,
      marketCode,
      isAvailable,
      sortPrice,
    });

  if (!isListProductsPaginatedRpcAvailable) {
    return runFallback();
  }

  const { data, error } = await supabase.rpc('list_products_paginated', {
    p_tenant_id: tenantId ?? undefined,
    p_search: search ?? undefined,
    p_search_field: searchField ?? 'name',
    p_category: category ?? undefined,
    p_brand: brand ?? undefined,
    p_vendor_code: vendorCode ?? undefined,
    p_market_code: marketCode ?? undefined,
    p_is_available: typeof isAvailable === 'boolean' ? isAvailable : undefined,
    p_sort_dir: sortPrice ?? 'asc',
    p_limit: limit,
    p_cursor_name: cursor?.name ?? undefined,
    p_cursor_id: cursor?.id ?? undefined,
  });

  if (error) {
    if (isMissingListProductsRpcError(error)) {
      isListProductsPaginatedRpcAvailable = false;
      return runFallback();
    }
    throw error;
  }

  const envelope =
    (data as { data?: Product[]; meta?: Record<string, unknown> } | null) ?? null;
  if (!envelope) {
    return buildEmptyProductPage(limit);
  }

  const meta = envelope.meta ?? {};

  return {
    data: envelope.data ?? [],
    meta: {
      has_more: Boolean(meta.has_more),
      next_cursor: parseProductListCursor(meta.next_cursor),
      limit: Number(meta.limit ?? limit) || limit,
    },
  };
};

const createProduct = async (payload: ProductCreateInput): Promise<Product> => {
  const scoped = await applyProductInsertScope(payload, new Map());
  const { data, error } = await supabase
    .from('products')
    .insert([buildProductPayload(scoped)])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product was not created.');
  }

  return data as Product;
};

const bulkCreateProducts = async (payloads: ProductCreateInput[]): Promise<Product[]> => {
  const parentCache = new Map<number, number>();
  const formatted: ReturnType<typeof buildProductPayload>[] = [];
  for (const payload of payloads) {
    const scoped = await applyProductInsertScope(payload, parentCache);
    formatted.push(buildProductPayload(scoped));
  }
  const { data, error } = await supabase.from('products').insert(formatted).select();

  if (error) {
    throw error;
  }

  return (data as Product[]) ?? [];
};

const getProductById = async (id: number, tenantId?: number | null): Promise<Product> => {
  if (typeof tenantId === 'number') {
    const { data, error } = await supabase.rpc('get_product_for_tenant', {
      p_id: id,
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    if (!data) {
      throw new Error('Product not found.');
    }

    return data as Product;
  }

  const { data, error } = await supabase.from('products').select('*').eq('id', id).single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product not found.');
  }

  return data as Product;
};

const updateProduct = async (payload: ProductUpdateInput): Promise<Product> => {
  const { id, ...rest } = payload;

  const updatePayload = buildProductUpdatePayload(rest);

  const { data, error } = await supabase
    .from('products')
    .update(updatePayload)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product was not updated.');
  }

  return data as Product;
};

const deleteProduct = async (payload: ProductDeleteInput): Promise<Product> => {
  const { data, error } = await supabase
    .from('products')
    .delete()
    .eq('id', payload.id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product was not deleted.');
  }

  return data as Product;
};

const listProductBrands = async ({
  vendorCode,
  vendorId,
  tenantId,
}: ListProductLookupParams = {}): Promise<ProductBrand[]> => {
  if (typeof tenantId !== 'number') {
    return [];
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null;
  const { data, error } = await supabase.rpc('list_product_brands_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: typeof vendorId === 'number' ? vendorId : null,
  });

  if (error) throw error;

  return (data as ProductBrand[] | null) ?? [];
};

const createProductBrand = async (payload: ProductBrandCreateInput): Promise<ProductBrand> => {
  const name = normalizeText(payload.name)?.toUpperCase() ?? '';
  if (!name) throw new Error('Brand name is required.');
  const vendorCode = normalizeText(payload.vendor_code)?.toUpperCase() ?? null;

  const insertData: ProductBrandCreateInput = {
    name,
    vendor_code: vendorCode,
    vendor_id: payload.vendor_id ?? null,
    tenant_id: payload.tenant_id ?? null,
  };

  const { data, error } = await supabase
    .from('product_brands')
    .insert([insertData])
    .select('*')
    .single();

  if (error) throw error;
  if (!data) throw new Error('Brand was not created.');
  return data as ProductBrand;
};

const updateProductBrand = async (payload: ProductBrandUpdateInput): Promise<ProductBrand> => {
  const patch: ProductBrandUpdateInput = { id: payload.id };
  if (payload.name !== undefined) patch.name = normalizeText(payload.name)?.toUpperCase() ?? '';
  if (payload.vendor_code !== undefined)
    patch.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null;
  if (payload.vendor_id !== undefined) patch.vendor_id = payload.vendor_id;
  if (payload.tenant_id !== undefined) patch.tenant_id = payload.tenant_id;

  const { data, error } = await supabase
    .from('product_brands')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single();

  if (error) throw error;
  if (!data) throw new Error('Brand was not updated.');
  return data as ProductBrand;
};

const deleteProductBrand = async (payload: ProductBrandDeleteInput): Promise<void> => {
  const { error } = await supabase.from('product_brands').delete().eq('id', payload.id);
  if (error) throw error;
};

const listProductCategories = async ({
  vendorCode,
  vendorId,
  tenantId,
}: ListProductLookupParams = {}): Promise<ProductCategory[]> => {
  if (typeof tenantId !== 'number') {
    return [];
  }

  const normalizedVendorCode = normalizeText(vendorCode)?.toUpperCase() ?? null;
  const { data, error } = await supabase.rpc('list_product_categories_for_tenant', {
    p_tenant_id: tenantId,
    p_vendor_code: normalizedVendorCode,
    p_vendor_id: typeof vendorId === 'number' ? vendorId : null,
  });

  if (error) throw error;

  return (data as ProductCategory[] | null) ?? [];
};

const createProductCategory = async (
  payload: ProductCategoryCreateInput,
): Promise<ProductCategory> => {
  const name = normalizeText(payload.name) ?? '';
  if (!name) throw new Error('Category name is required.');
  const vendorCode = normalizeText(payload.vendor_code)?.toUpperCase() ?? null;

  const insertData: ProductCategoryCreateInput = {
    name,
    vendor_code: vendorCode,
    vendor_id: payload.vendor_id ?? null,
    tenant_id: payload.tenant_id ?? null,
  };

  const { data, error } = await supabase
    .from('product_categories')
    .insert([insertData])
    .select('*')
    .single();

  if (error) throw error;
  if (!data) throw new Error('Category was not created.');
  return data as ProductCategory;
};

const updateProductCategory = async (
  payload: ProductCategoryUpdateInput,
): Promise<ProductCategory> => {
  const patch: ProductCategoryUpdateInput = { id: payload.id };
  if (payload.name !== undefined) patch.name = normalizeText(payload.name) ?? '';
  if (payload.vendor_code !== undefined)
    patch.vendor_code = normalizeText(payload.vendor_code)?.toUpperCase() ?? null;
  if (payload.vendor_id !== undefined) patch.vendor_id = payload.vendor_id;
  if (payload.tenant_id !== undefined) patch.tenant_id = payload.tenant_id;

  const { data, error } = await supabase
    .from('product_categories')
    .update(patch)
    .eq('id', payload.id)
    .select('*')
    .single();

  if (error) throw error;
  if (!data) throw new Error('Category was not updated.');
  return data as ProductCategory;
};

const deleteProductCategory = async (payload: ProductCategoryDeleteInput): Promise<void> => {
  const { error } = await supabase.from('product_categories').delete().eq('id', payload.id);
  if (error) throw error;
};

const escapePostgrestInValue = (value: string) => `"${value.replace(/"/g, '\\"')}"`;

const lookupProductsByCodes = async ({
  codes,
  tenantId,
  searchField = 'auto',
}: {
  codes: string[];
  tenantId: number;
  searchField?: 'auto' | 'barcode' | 'product_code' | 'id';
}): Promise<Product[]> => {
  const uniqueCodes = [...new Set(codes.map((c) => c.trim()).filter((c) => c.length > 0))];
  if (uniqueCodes.length === 0) return [];

  const scopeTenantId = await resolveProductScopeTenantId(tenantId);
  const chunkSize = 100;
  const results: Product[] = [];
  const seenIds = new Set<number>();

  for (let i = 0; i < uniqueCodes.length; i += chunkSize) {
    const chunk = uniqueCodes.slice(i, i + chunkSize);

    const clauses: string[] = [];
    if (searchField === 'barcode' || searchField === 'auto') {
      const inList = chunk.map(escapePostgrestInValue).join(',');
      clauses.push(`barcode.in.(${inList})`);
    }
    if (searchField === 'product_code' || searchField === 'auto') {
      const inList = chunk.map(escapePostgrestInValue).join(',');
      clauses.push(`product_code.in.(${inList})`);
    }
    if (searchField === 'id' || searchField === 'auto') {
      const numericIds = chunk
        .map((c) => c.replace(/^#/, ''))
        .filter((c) => /^\d+$/.test(c))
        .map((c) => Number(c));
      if (numericIds.length > 0) {
        clauses.push(`id.in.(${numericIds.join(',')})`);
      }
    }

    if (clauses.length === 0) continue;

    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('parent_tenant_id', scopeTenantId)
      .or(clauses.join(','));

    if (error) throw error;

    for (const row of (data as Product[] | null) ?? []) {
      if (seenIds.has(row.id)) continue;
      seenIds.add(row.id);
      results.push(row);
    }
  }

  return results;
};

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
  lookupProductsByCodes,
  getProductById,
  createProduct,
  bulkCreateProducts,
  updateProduct,
  deleteProduct,
};
