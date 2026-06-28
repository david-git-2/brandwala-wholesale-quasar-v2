import { supabase } from 'src/boot/supabase';
import type { ThriftStock, ThriftStockMeasurements } from '../types';

export interface ThriftStockListMeta {
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface ThriftStockListParams {
  tenantId: number;
  page?: number;
  pageSize?: number;
  search?: string;
  status?: string | null;
  condition?: string | null;
}

export interface ThriftStockListResult {
  data: ThriftStock[];
  meta: ThriftStockListMeta;
}

export interface ThriftStockDeleteTarget {
  id: number;
  imageUrl?: string | undefined;
  driveFileId?: string | undefined;
}

interface ThriftStockDbRow {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  brand_name?: string;
  category_id: number;
  type_id: number;
  section: string;
  shelf_id: number;
  color: string;
  size: string;
  condition: string;
  barcode: string;
  stock_type: string;
  quantity: number;
  box_id?: number;
  product_weight?: number;
  extra_weight?: number;
  status: string;
  note?: string;
  inserted_by: string;
  created_at: string;
  updated_at: string;
  thrift_pricings?: Array<{
    cost_of_goods_sold: number;
    target_price: number;
    listed_unit_price: number;
    is_listed_price_manual?: boolean;
    extra_expense_cost?: number;
  }>;
  thrift_stock_images?: Array<{
    image_url: string;
    drive_file_id?: string | null;
    is_primary: boolean;
  }>;
  thrift_stock_measurements?: ThriftStockMeasurements[] | ThriftStockMeasurements | null;
  origin_unit_price?: number;
  extra_origin_unit_price?: number;
  additional_charges_cost?: number;
}

interface ThriftStockPaginatedRow extends ThriftStockDbRow {
  pricing?: {
    cost_of_goods_sold: number;
    target_price: number;
    listed_unit_price: number;
    is_listed_price_manual?: boolean;
    extra_expense_cost?: number;
  };
  image_url?: string | null;
  drive_file_id?: string | null;
  measurements?: ThriftStockMeasurements | null;
}

export interface ThriftStockPricingInput {
  cost_of_goods_sold: number;
  target_price: number;
  listed_unit_price: number;
  is_listed_price_manual?: boolean;
  extra_expense_cost?: number;
}

async function upsertStockPricing(
  stockId: number,
  pricing: ThriftStockPricingInput,
  insertedBy: string,
) {
  const { data: existing, error: fetchError } = await supabase
    .from('thrift_pricings')
    .select('id')
    .eq('stock_id', stockId)
    .maybeSingle();
  if (fetchError) throw fetchError;

  const pricingRow = {
    stock_id: stockId,
    cost_of_goods_sold: pricing.cost_of_goods_sold,
    target_price: pricing.target_price,
    listed_unit_price: pricing.listed_unit_price,
    is_listed_price_manual: pricing.is_listed_price_manual ?? false,
    extra_expense_cost: pricing.extra_expense_cost ?? 0,
    inserted_by: insertedBy,
  };

  if (existing?.id) {
    const { data, error } = await supabase
      .from('thrift_pricings')
      .update(pricingRow)
      .eq('stock_id', stockId)
      .select()
      .single();
    if (error) throw error;
    return data;
  }

  const { data, error } = await supabase
    .from('thrift_pricings')
    .insert(pricingRow)
    .select()
    .single();
  if (error) throw error;
  return data;
}

function escapeIlike(value: string): string {
  return value.replace(/[%_(),]/g, ' ').trim();
}

function shouldFallbackToDirectQuery(error: {
  code?: string;
  message?: string;
  status?: number;
}): boolean {
  const message = error.message ?? '';

  if (
    error.code === 'PGRST202' ||
    /could not find the function/i.test(message)
  ) {
    return true;
  }

  if (
    error.code === '57014' ||
    /statement timeout|canceling statement/i.test(message)
  ) {
    return true;
  }

  if (error.status === 502 || error.status === 504) {
    return true;
  }

  return /gateway timeout|bad gateway|504|502/i.test(message);
}

function mapPaginatedRows(rows: ThriftStockPaginatedRow[]): ThriftStock[] {
  return rows.map((stock) => {
    const pricing = stock.pricing ?? stock.thrift_pricings?.[0] ?? {
      cost_of_goods_sold: 0,
      target_price: 0,
      listed_unit_price: 0,
      is_listed_price_manual: false,
      extra_expense_cost: 0,
    };
    const primaryImage =
      stock.thrift_stock_images?.find((img) => img.is_primary) ||
      stock.thrift_stock_images?.[0];

    const measurements = stock.measurements ??
      (Array.isArray(stock.thrift_stock_measurements)
        ? stock.thrift_stock_measurements[0]
        : stock.thrift_stock_measurements) ??
      null;

    return {
      ...(stock as unknown as ThriftStock),
      pricing: {
        cost_of_goods_sold: Number(pricing.cost_of_goods_sold) || 0,
        target_price: Number(pricing.target_price) || 0,
        listed_unit_price: Number(pricing.listed_unit_price) || 0,
        is_listed_price_manual: !!pricing.is_listed_price_manual,
        extra_expense_cost: Number(pricing.extra_expense_cost) || 0,
      },
      image_url: stock.image_url || primaryImage?.image_url || undefined,
      drive_file_id: stock.drive_file_id || primaryImage?.drive_file_id || undefined,
      measurements,
    };
  }) as ThriftStock[];
}

function mapRpcPayload(payload: {
  data: ThriftStockPaginatedRow[];
  meta: ThriftStockListMeta;
}): ThriftStockListResult {
  return {
    data: mapPaginatedRows(payload.data || []),
    meta: {
      total: Number(payload.meta?.total) || 0,
      page: Number(payload.meta?.page) || 1,
      page_size: Number(payload.meta?.page_size) || 20,
      total_pages: Number(payload.meta?.total_pages) || 0,
    },
  };
}

async function fetchStocksPaginatedViaRpc(
  params: ThriftStockListParams,
): Promise<ThriftStockListResult> {
  const { data, error } = await supabase.rpc('list_thrift_stocks_paginated', {
    p_tenant_id: params.tenantId,
    p_page: params.page ?? 1,
    p_page_size: params.pageSize ?? 20,
    p_search: params.search?.trim() || null,
    p_status: params.status || null,
    p_condition: params.condition || null,
  });
  if (error) throw error;

  return mapRpcPayload(
    data as {
      data: ThriftStockPaginatedRow[];
      meta: ThriftStockListMeta;
    },
  );
}

async function fetchStocksPaginatedDirect(
  params: ThriftStockListParams,
): Promise<ThriftStockListResult> {
  const page = params.page ?? 1;
  const pageSize = params.pageSize ?? 20;
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;
  const search = escapeIlike(params.search?.trim() || '');

  let query = supabase
    .from('thrift_stocks')
    .select(
      `
        *,
        thrift_pricings (
          cost_of_goods_sold,
          target_price,
          listed_unit_price,
          is_listed_price_manual,
          extra_expense_cost
        ),
        thrift_stock_images (
          image_url,
          drive_file_id,
          is_primary
        ),
        thrift_stock_measurements (
          *
        )
      `,
      { count: 'exact' },
    )
    .eq('tenant_id', params.tenantId)
    .order('created_at', { ascending: false });

  if (params.status) {
    query = query.eq('status', params.status);
  }

  if (params.condition) {
    query = query.eq('condition', params.condition);
  }

  if (search) {
    query = query.or(
      `name.ilike.%${search}%,brand_name.ilike.%${search}%,barcode.ilike.%${search}%`,
    );
  }

  const { data, error, count } = await query.range(from, to);
  if (error) throw error;

  const total = count ?? 0;
  const totalPages = total === 0 ? 0 : Math.ceil(total / pageSize);

  return {
    data: mapPaginatedRows((data || []) as ThriftStockPaginatedRow[]),
    meta: {
      total,
      page,
      page_size: pageSize,
      total_pages: totalPages,
    },
  };
}

export const thriftStockRepository = {
  async fetchStocksPaginated(params: ThriftStockListParams): Promise<ThriftStockListResult> {
    try {
      return await fetchStocksPaginatedViaRpc(params);
    } catch (error) {
      if (!shouldFallbackToDirectQuery(error as { code?: string; message?: string; status?: number })) {
        throw error;
      }

      console.warn(
        'list_thrift_stocks_paginated RPC failed; falling back to direct query.',
        error,
      );
      return fetchStocksPaginatedDirect(params);
    }
  },

  async fetchStocks(tenantId: number): Promise<ThriftStock[]> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('*, thrift_pricings(*), thrift_stock_images(*), thrift_stock_measurements(*)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;

    return ((data || []) as unknown as ThriftStockDbRow[]).map((stock) => {
      const primaryImage = stock.thrift_stock_images?.find((img) => img.is_primary) || stock.thrift_stock_images?.[0];
      const measurements = Array.isArray(stock.thrift_stock_measurements)
        ? stock.thrift_stock_measurements[0]
        : stock.thrift_stock_measurements;

      return {
        ...stock,
        pricing: stock.thrift_pricings?.[0] || stock.thrift_pricings || undefined,
        image_url: primaryImage?.image_url || undefined,
        drive_file_id: primaryImage?.drive_file_id || undefined,
        measurements: measurements || null,
      };
    }) as unknown as ThriftStock[];
  },

  async createStock(
    stock: Partial<ThriftStock>,
    pricing: ThriftStockPricingInput,
    imageUrl?: string,
    driveFileId?: string,
  ): Promise<ThriftStock> {
    const { data: stockData, error: stockError } = await supabase
      .from('thrift_stocks')
      .insert(stock)
      .select()
      .single();
    if (stockError) throw stockError;

    const pricingData = await upsertStockPricing(
      stockData.id,
      pricing,
      stockData.inserted_by,
    );

    if (imageUrl) {
      const { error: imageError } = await supabase
        .from('thrift_stock_images')
        .insert({
          stock_id: stockData.id,
          image_url: imageUrl,
          drive_file_id: driveFileId || null,
          is_primary: true,
          inserted_by: stockData.inserted_by,
        });
      if (imageError) console.error('Failed to link image to stock:', imageError);
    }

    return {
      ...stockData,
      pricing: pricingData,
      image_url: imageUrl,
      drive_file_id: driveFileId,
      measurements: null,
    } as ThriftStock;
  },

  async updateStock(
    id: number,
    stock: Partial<ThriftStock>,
    pricing: ThriftStockPricingInput,
    imageUrl?: string | null,
    driveFileId?: string | null,
  ): Promise<ThriftStock> {
    let stockData: ThriftStock;

    if (Object.keys(stock).length > 0) {
      const { data, error: stockError } = await supabase
        .from('thrift_stocks')
        .update(stock)
        .eq('id', id)
        .select()
        .single();
      if (stockError) throw stockError;
      stockData = data as ThriftStock;
    } else {
      const { data, error: stockError } = await supabase
        .from('thrift_stocks')
        .select('*')
        .eq('id', id)
        .single();
      if (stockError) throw stockError;
      stockData = data as ThriftStock;
    }

    const pricingData = await upsertStockPricing(id, pricing, stockData.inserted_by);

    let resolvedImageUrl: string | undefined;
    let resolvedDriveFileId: string | undefined;
    if (imageUrl !== undefined) {
      if (imageUrl) {
        await thriftStockRepository.upsertPrimaryStockImage(
          id,
          imageUrl,
          stockData.inserted_by,
          driveFileId,
        );
        resolvedImageUrl = imageUrl;
        resolvedDriveFileId = driveFileId || undefined;
      } else {
        await thriftStockRepository.deletePrimaryStockImage(id);
        resolvedImageUrl = undefined;
        resolvedDriveFileId = undefined;
      }
    }

    return {
      ...stockData,
      pricing: pricingData,
      ...(resolvedImageUrl !== undefined ? { image_url: resolvedImageUrl } : {}),
      ...(resolvedDriveFileId !== undefined ? { drive_file_id: resolvedDriveFileId } : {}),
    } as ThriftStock;
  },

  async upsertPrimaryStockImage(
    stockId: number,
    imageUrl: string,
    insertedBy: string,
    driveFileId?: string | null,
  ): Promise<void> {
    const { data: existing, error: fetchError } = await supabase
      .from('thrift_stock_images')
      .select('id')
      .eq('stock_id', stockId)
      .eq('is_primary', true)
      .maybeSingle();
    if (fetchError) throw fetchError;

    if (existing) {
      const { error } = await supabase
        .from('thrift_stock_images')
        .update({
          image_url: imageUrl,
          drive_file_id: driveFileId ?? null,
          inserted_by: insertedBy,
        })
        .eq('id', existing.id);
      if (error) throw error;
      return;
    }

    const { error } = await supabase
      .from('thrift_stock_images')
      .insert({
        stock_id: stockId,
        image_url: imageUrl,
        drive_file_id: driveFileId ?? null,
        is_primary: true,
        inserted_by: insertedBy,
      });
    if (error) throw error;
  },

  async deletePrimaryStockImage(stockId: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_stock_images')
      .delete()
      .eq('stock_id', stockId)
      .eq('is_primary', true);
    if (error) throw error;
  },

  async updateStockStatus(id: number, status: string): Promise<void> {
    const { error } = await supabase
      .from('thrift_stocks')
      .update({ status })
      .eq('id', id);
    if (error) throw error;
  },

  async deleteStock(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_stocks')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },

  async deleteStocks(ids: number[]): Promise<void> {
    if (!ids.length) return;
    const { error } = await supabase
      .from('thrift_stocks')
      .delete()
      .in('id', ids);
    if (error) throw error;
  },

  async fetchDeleteTargets(ids: number[]): Promise<ThriftStockDeleteTarget[]> {
    if (!ids.length) return [];

    const { data, error } = await supabase
      .from('thrift_stocks')
      .select(`
        id,
        thrift_stock_images (
          image_url,
          drive_file_id,
          is_primary
        )
      `)
      .in('id', ids);

    if (error) throw error;

    return (data || []).map((row) => {
      const images = (row.thrift_stock_images as Array<{
        image_url: string;
        drive_file_id: string | null;
        is_primary: boolean;
      }>) || [];
      const primary = images.find((img) => img.is_primary) || images[0];

      return {
        id: row.id as number,
        imageUrl: primary?.image_url,
        driveFileId: primary?.drive_file_id ?? undefined,
      };
    });
  },

  async upsertStockMeasurements(
    stockId: number,
    measurements: Partial<ThriftStockMeasurements>,
    tenantId: number,
  ): Promise<ThriftStockMeasurements> {
    const { data, error } = await supabase
      .from('thrift_stock_measurements')
      .upsert({
        stock_id: stockId,
        tenant_id: tenantId,
        bust_in: measurements.bust_in ?? null,
        waist_in: measurements.waist_in ?? null,
        hips_in: measurements.hips_in ?? null,
        length_in: measurements.length_in ?? null,
        shoulder_width_in: measurements.shoulder_width_in ?? null,
        sleeve_length_in: measurements.sleeve_length_in ?? null,
        arm_circumference_in: measurements.arm_circumference_in ?? null,
        hem_width_in: measurements.hem_width_in ?? null,
        neck_opening_in: measurements.neck_opening_in ?? null,
        sleeve_type: measurements.sleeve_type ?? null,
        neckline: measurements.neckline ?? null,
        dress_style: measurements.dress_style ?? null,
        fabric_stretch: measurements.fabric_stretch ?? null,
        lining: measurements.lining ?? null,
        closure_type: measurements.closure_type ?? null,
        measurement_notes: measurements.measurement_notes ?? null,
      })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftStockMeasurements;
  },

  async deleteStockMeasurements(stockId: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_stock_measurements')
      .delete()
      .eq('stock_id', stockId);
    if (error) throw error;
  },

  async fetchStocksByShipment(tenantId: number, shipmentId: number): Promise<ThriftStock[]> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('*, thrift_pricings(*), thrift_stock_images(*), thrift_stock_measurements(*)')
      .eq('tenant_id', tenantId)
      .eq('shipment_id', shipmentId)
      .order('created_at', { ascending: false });
    if (error) throw error;

    return ((data || []) as unknown as ThriftStockDbRow[]).map((stock) => {
      const primaryImage = stock.thrift_stock_images?.find((img) => img.is_primary) || stock.thrift_stock_images?.[0];
      const measurements = Array.isArray(stock.thrift_stock_measurements)
        ? stock.thrift_stock_measurements[0]
        : stock.thrift_stock_measurements;

      return {
        ...stock,
        pricing: stock.thrift_pricings?.[0] || stock.thrift_pricings || undefined,
        image_url: primaryImage?.image_url || undefined,
        drive_file_id: primaryImage?.drive_file_id || undefined,
        measurements: measurements || null,
      };
    }) as unknown as ThriftStock[];
  },
};
