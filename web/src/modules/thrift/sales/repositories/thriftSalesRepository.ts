import { supabase } from 'src/boot/supabase';

export interface AvailableStockItem {
  id: number;
  name: string;
  barcode: string;
  availableQuantity: number;
  defaultSellPrice: number;
  landedCost: number;
  category: string;
  shipmentId: number;
  status: string;
  shipmentName?: string | undefined;
  brandName?: string | undefined;
  type?: string | undefined;
  color?: string | undefined;
  size?: string | undefined;
  condition?: string | undefined;
  section?: string | undefined;
  shelfCode?: string | undefined;
  boxName?: string | undefined;
  imageUrl?: string | undefined;
}

export interface CreateSalesInvoiceInput {
  tenantId: number;
  customerName?: string | undefined;
  customerPhone?: string | undefined;
  date: string;
  paymentMethod: string;
  paymentStatus: string;
  notes?: string | undefined;
  createdBy: string;
  totalInvoiceAmount: number;
  items: Array<{
    stockId: number;
    sellPrice: number;
    discountAmount: number;
    finalPrice: number;
    landedUnitCostAtSale: number;
    quantity: number;
    netProfit: number;
  }>;
}

export interface ThriftSalesInvoiceListItem {
  id: number;
  invoiceNumber: string;
  customerName: string | null;
  customerPhone: string | null;
  date: string;
  paymentMethod: string;
  paymentStatus: string;
  totalInvoiceAmount: number;
  createdBy: string;
  notes: string | null;
  itemCount: number;
  createdAt: string;
  status: 'ACTIVE' | 'RETURNED' | 'STAFF_MISTAKE' | string;
  revertedAt: string | null;
  revertedBy: string | null;
  revertReason: string | null;
  revertNotes: string | null;
}

export interface ThriftSalesInvoiceItemDetail {
  id: number;
  stockId: number;
  stockName: string | null;
  barcode: string | null;
  sellPrice: number;
  discountAmount: number;
  finalPrice: number;
  quantity: number;
  landedUnitCostAtSale: number;
  netProfit: number;
}

export interface ThriftSalesInvoiceDetail extends Omit<ThriftSalesInvoiceListItem, 'itemCount'> {
  items: ThriftSalesInvoiceItemDetail[];
}

export type ThriftSalesRevertReason = 'RETURN' | 'STAFF_MISTAKE';

function mapInvoiceRow(row: any): Omit<ThriftSalesInvoiceListItem, 'itemCount'> {
  return {
    id: row.id,
    invoiceNumber: row.invoice_number,
    customerName: row.customer_name ?? null,
    customerPhone: row.customer_phone ?? null,
    date: row.date,
    paymentMethod: row.payment_method,
    paymentStatus: row.payment_status,
    totalInvoiceAmount: Number(row.total_invoice_amount) || 0,
    createdBy: row.created_by || '',
    notes: row.notes ?? null,
    createdAt: row.created_at,
    status: row.status || 'ACTIVE',
    revertedAt: row.reverted_at ?? null,
    revertedBy: row.reverted_by ?? null,
    revertReason: row.revert_reason ?? null,
    revertNotes: row.revert_notes ?? null,
  };
}

export interface ThriftSalesInvoiceListMeta {
  page: number;
  total: number;
  page_size: number;
  total_pages: number;
}

export interface ThriftSalesInvoiceListResult {
  data: ThriftSalesInvoiceListItem[];
  meta: ThriftSalesInvoiceListMeta;
}

export interface ListSalesInvoicesParams {
  tenantId: number;
  search?: string | undefined;
  page?: number | undefined;
  pageSize?: number | undefined;
}

export const thriftSalesRepository = {
  /**
   * List sales invoices for a tenant (newest first), server-paginated via RPC
   */
  async listSalesInvoices(params: ListSalesInvoicesParams): Promise<ThriftSalesInvoiceListResult> {
    const page = params.page ?? 1;
    const pageSize = params.pageSize ?? 20;

    const { data, error } = await supabase.rpc('list_thrift_sales_invoices_paginated', {
      p_tenant_id: params.tenantId,
      p_page: page,
      p_page_size: pageSize,
      p_search: params.search?.trim() || null,
    });

    if (error) throw error;

    const payload = (data ?? {}) as {
      data?: any[];
      meta?: Partial<ThriftSalesInvoiceListMeta>;
    };

    return {
      data: (payload.data || []).map((row: any) => ({
        ...mapInvoiceRow(row),
        itemCount: Number(row.item_count ?? 0),
      })),
      meta: {
        page: Number(payload.meta?.page) || page,
        total: Number(payload.meta?.total) || 0,
        page_size: Number(payload.meta?.page_size) || pageSize,
        total_pages: Number(payload.meta?.total_pages) || 0,
      },
    };
  },

  /**
   * Get a single sales invoice with line items
   */
  async getSalesInvoice(tenantId: number, invoiceId: number): Promise<ThriftSalesInvoiceDetail> {
    const { data, error } = await supabase
      .from('thrift_sales_invoices')
      .select(
        `
        id,
        invoice_number,
        customer_name,
        customer_phone,
        date,
        payment_method,
        payment_status,
        total_invoice_amount,
        created_by,
        notes,
        created_at,
        status,
        reverted_at,
        reverted_by,
        revert_reason,
        revert_notes,
        thrift_sales_invoice_items (
          id,
          stock_id,
          sell_price,
          discount_amount,
          final_price,
          quantity,
          landed_unit_cost_at_sale,
          net_profit,
          thrift_stocks (
            id,
            name,
            barcode
          )
        )
      `,
      )
      .eq('tenant_id', tenantId)
      .eq('id', invoiceId)
      .single();

    if (error) throw error;
    if (!data) throw new Error('Invoice not found');

    const items = ((data as any).thrift_sales_invoice_items || []).map((item: any) => {
      const stock = Array.isArray(item.thrift_stocks)
        ? item.thrift_stocks[0]
        : item.thrift_stocks;
      return {
        id: item.id,
        stockId: item.stock_id,
        stockName: stock?.name ?? null,
        barcode: stock?.barcode ?? null,
        sellPrice: Number(item.sell_price) || 0,
        discountAmount: Number(item.discount_amount) || 0,
        finalPrice: Number(item.final_price) || 0,
        quantity: Number(item.quantity) || 0,
        landedUnitCostAtSale: Number(item.landed_unit_cost_at_sale) || 0,
        netProfit: Number(item.net_profit) || 0,
      };
    });

    return {
      ...mapInvoiceRow(data),
      items,
    };
  },

  /**
   * Revert an ACTIVE invoice (RETURN or STAFF_MISTAKE)
   */
  async revertSalesInvoice(input: {
    tenantId: number;
    invoiceId: number;
    reason: ThriftSalesRevertReason;
    revertedBy: string;
    notes?: string | undefined;
  }): Promise<{ id: number; invoiceNumber: string; status: string }> {
    const { data, error } = await supabase.rpc('revert_thrift_sales_invoice', {
      p_tenant_id: input.tenantId,
      p_invoice_id: input.invoiceId,
      p_reason: input.reason,
      p_reverted_by: input.revertedBy,
      p_notes: input.notes || null,
    });

    if (error) throw error;

    const result = data as any;
    return {
      id: Number(result?.id ?? input.invoiceId),
      invoiceNumber: String(result?.invoice_number ?? ''),
      status: String(result?.status ?? ''),
    };
  },

  /**
   * Create a sales invoice, insert line items, mark stock as SOLD, and insert revenue ledger entry
   */
  async createSalesInvoice(input: CreateSalesInvoiceInput): Promise<{ id: number; invoiceNumber: string }> {
    const { data, error } = await supabase.rpc('create_thrift_sales_invoice', {
      p_tenant_id: input.tenantId,
      p_customer_name: input.customerName || null,
      p_customer_phone: input.customerPhone || null,
      p_date: input.date,
      p_payment_method: input.paymentMethod,
      p_payment_status: input.paymentStatus,
      p_notes: input.notes || null,
      p_created_by: input.createdBy,
      p_total_invoice_amount: input.totalInvoiceAmount,
      p_items: input.items.map((item) => ({
        stock_id: item.stockId,
        sell_price: item.sellPrice,
        discount_amount: item.discountAmount,
        final_price: item.finalPrice,
        landed_unit_cost: item.landedUnitCostAtSale,
        quantity: item.quantity,
        net_profit: item.netProfit,
      })),
    });

    if (error) throw error;
    if (!data) throw new Error('Failed to create sales invoice');

    const result = data as any;
    return {
      id: Number(result.id ?? result),
      invoiceNumber: String(result.invoice_number ?? ''),
    };
  },

  /**
   * Search stocks for invoice (AVAILABLE + SOLD so sold matches are visible)
   */
  async searchAvailableStocks(tenantId: number, search?: string): Promise<AvailableStockItem[]> {

    const settingsPromise = supabase
      .from('thrift_settings')
      .select('hand_tag_unit_cost, sticker_unit_cost')
      .eq('tenant_id', tenantId)
      .maybeSingle();

    let query = supabase
      .from('thrift_stocks')
      .select(
        `
        id,
        name,
        brand_name,
        barcode,
        quantity,
        product_weight,
        extra_weight,
        origin_unit_price,
        extra_origin_unit_price,
        additional_charges_cost,
        color,
        size,
        condition,
        section,
        shipment_id,
        category_id,
        status,
        thrift_pricings (
          cost_of_goods_sold,
          target_price,
          listed_unit_price
        ),
        thrift_shipments (
          id,
          name,
          product_conversion_rate,
          cargo_conversion_rate,
          cargo_rate,
          total_cargo_weight_kg,
          labor_total_cost,
          transportation_total_cost,
          washing_total_cost,
          default_markup_rate,
          thrift_stocks (
            id,
            quantity,
            product_weight,
            extra_weight
          )
        ),
        thrift_categories (
          name
        ),
        thrift_types (
          name
        ),
        thrift_shelves (
          shelf_code
        ),
        thrift_boxes (
          name
        ),
        thrift_stock_images (
          image_url,
          is_primary
        )
      `,
      )
      .eq('tenant_id', tenantId)
      .in('status', ['AVAILABLE', 'SOLD'])
      .order('created_at', { ascending: false })
      .limit(50);

    const cleanSearch = search?.trim();
    if (cleanSearch) {
      const needle = cleanSearch.replace(/[%_(),]/g, ' ');
      query = query.or(
        `name.ilike.%${needle}%,barcode.ilike.%${needle}%,brand_name.ilike.%${needle}%,color.ilike.%${needle}%,size.ilike.%${needle}%`,
      );
    }

    const [{ data: settingsData }, { data, error }] = await Promise.all([
      settingsPromise,
      query,
    ]);

    if (error) throw error;

    const handTagCost = Number(settingsData?.hand_tag_unit_cost) || 0;
    const stickerCost = Number(settingsData?.sticker_unit_cost) || 0;

    return (data || []).map((row: any) => {
      const pricing = Array.isArray(row.thrift_pricings)
        ? row.thrift_pricings[0]
        : row.thrift_pricings;
      const shipmentObj = Array.isArray(row.thrift_shipments)
        ? row.thrift_shipments[0]
        : row.thrift_shipments;
      const categoryObj = Array.isArray(row.thrift_categories)
        ? row.thrift_categories[0]
        : row.thrift_categories;
      const typeObj = Array.isArray(row.thrift_types)
        ? row.thrift_types[0]
        : row.thrift_types;
      const shelfObj = Array.isArray(row.thrift_shelves)
        ? row.thrift_shelves[0]
        : row.thrift_shelves;
      const boxObj = Array.isArray(row.thrift_boxes)
        ? row.thrift_boxes[0]
        : row.thrift_boxes;
      const images = Array.isArray(row.thrift_stock_images)
        ? row.thrift_stock_images
        : row.thrift_stock_images
          ? [row.thrift_stock_images]
          : [];
      const primaryImg = images.find((img: any) => img.is_primary) || images[0];

      // 1. Calculate Product Cost
      const originPrice = Number(row.origin_unit_price) || 0;
      const extraOriginPrice = Number(row.extra_origin_unit_price) || 0;
      const prodConv = Number(shipmentObj?.product_conversion_rate) || 1.0;
      const productUnitCost = (originPrice + extraOriginPrice) * prodConv;

      // 2. Calculate Shipment Total Units (U) and Total Weight (kg) from embedded shipment stocks
      const shipmentStocks: any[] = Array.isArray(shipmentObj?.thrift_stocks)
        ? shipmentObj.thrift_stocks
        : [];
      
      let U = 0;
      let shipmentTotalWeightKg = 0;
      for (const s of shipmentStocks) {
        const q = Number(s.quantity) > 0 ? Number(s.quantity) : 1;
        U += q;
        const w = ((Number(s.product_weight) || 0) + (Number(s.extra_weight) || 0)) / 1000;
        shipmentTotalWeightKg += w * q;
      }
      if (U <= 0) U = 1;

      // 3. Calculate Cargo Share per Unit
      const totalCargoWeightKg = Number(shipmentObj?.total_cargo_weight_kg) || 0;
      const cargoRate = Number(shipmentObj?.cargo_rate) || 0;
      const cargoConv = Number(shipmentObj?.cargo_conversion_rate) || 1.0;
      const totalCargoCost = totalCargoWeightKg * cargoRate * cargoConv;

      const qty = Number(row.quantity) > 0 ? Number(row.quantity) : 1;
      const itemUnitWeightKg = ((Number(row.product_weight) || 0) + (Number(row.extra_weight) || 0)) / 1000;
      const itemLineWeightKg = itemUnitWeightKg * qty;

      let cargoSharePerUnit = 0;
      if (totalCargoCost > 0) {
        if (shipmentTotalWeightKg > 0 && itemLineWeightKg > 0) {
          cargoSharePerUnit = ((itemLineWeightKg / shipmentTotalWeightKg) * totalCargoCost) / qty;
        } else {
          cargoSharePerUnit = totalCargoCost / U;
        }
      }

      // 4. Calculate Ops Share per Unit (Labor + Transport + Washing divided by U, plus Hand Tag & Sticker unit costs)
      const laborCost = Number(shipmentObj?.labor_total_cost) || 0;
      const transportCost = Number(shipmentObj?.transportation_total_cost) || 0;
      const washingCost = Number(shipmentObj?.washing_total_cost) || 0;
      const opsSharePerUnit = (laborCost + transportCost + washingCost) / U + handTagCost + stickerCost;

      // 5. Total Computed Landed Cost
      const additionalCharges = Number(row.additional_charges_cost) || 0;
      const computedLandedCost = productUnitCost + cargoSharePerUnit + opsSharePerUnit + additionalCharges;

      // Landed cost: Use computedLandedCost first, fallback to rawCogs if computedLandedCost is 0
      const rawCogs = Number(pricing?.cost_of_goods_sold);
      const landedCost = computedLandedCost > 0 ? computedLandedCost : rawCogs > 0 ? rawCogs : productUnitCost + additionalCharges;

      const defaultSellPrice =
        Number(pricing?.listed_unit_price) ||
        Number(pricing?.target_price) ||
        (landedCost > 0 ? Math.round(landedCost * 1.5) : 0);

      return {
        id: row.id,
        name: row.name || 'Unnamed Item',
        barcode: row.barcode || 'NO-BARCODE',
        availableQuantity: qty,
        defaultSellPrice,
        landedCost,
        category: categoryObj?.name || 'Uncategorized',
        status: row.status || 'AVAILABLE',
        brandName: row.brand_name || undefined,
        type: typeObj?.name || undefined,
        color: row.color || undefined,
        size: row.size || undefined,
        condition: row.condition || undefined,
        section: row.section || undefined,
        shelfCode: shelfObj?.shelf_code || undefined,
        boxName: boxObj?.name || undefined,
        imageUrl: primaryImg?.image_url || undefined,
        shipmentId: row.shipment_id || 0,
        shipmentName: shipmentObj?.name || undefined,
      };
    });
  },
};





