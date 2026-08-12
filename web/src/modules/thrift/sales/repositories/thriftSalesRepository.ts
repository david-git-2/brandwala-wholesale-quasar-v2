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
  heldForPhone?: string | null;
  heldForName?: string | null;
}

export type ThriftSaleChannel = 'IN_STORE' | 'ONLINE';
export type ThriftCourierPaidBy = 'CUSTOMER' | 'SHOP';
export type ThriftDeliveryStatus =
  | 'PENDING'
  | 'READY'
  | 'IN_TRANSIT'
  | 'DELIVERED'
  | 'RETURNED';

export interface ThriftCustomerAddressParts {
  district?: string | undefined;
  thana?: string | undefined;
  post_code?: string | undefined;
}

export interface ThriftCustomerSearchItem {
  id: number;
  name: string | null;
  phone: string | null;
  phoneNormalized: string | null;
  secondaryPhone: string | null;
  address: string | null;
  addressParts: ThriftCustomerAddressParts;
  notes: string | null;
}

export interface CreateSalesInvoiceInput {
  tenantId: number;
  saleChannel?: ThriftSaleChannel | undefined;
  customerName?: string | undefined;
  customerPhone?: string | undefined;
  customerSecondaryPhone?: string | undefined;
  customerAddress?: string | undefined;
  customerAddressParts?: ThriftCustomerAddressParts | undefined;
  customerNotes?: string | undefined;
  date: string;
  notes?: string | undefined;
  createdBy: string;
  totalInvoiceAmount: number;
  /** Online only — Offline RPC forces 0. */
  courierAmount?: number | undefined;
  courierPaidBy?: ThriftCourierPaidBy | null | undefined;
  packingAmount?: number | undefined;
  packingPaidBy?: ThriftCourierPaidBy | null | undefined;
  codFeeAmount?: number | undefined;
  codFeePaidBy?: ThriftCourierPaidBy | null | undefined;
  courierProvider?: string | undefined;
  courierProviderId?: number | null | undefined;
  meta?: Record<string, unknown> | undefined;
  /** @deprecated Prefer courierAmount. */
  courierCodAmount?: number | undefined;
  /** Online COD only; deducted from cod_expected. Offline / no risk → 0. */
  advanceAmount?: number | undefined;
  advanceNote?: string | undefined;
  items: Array<{
    stockId: number;
    sellPrice: number;
    discountAmount: number;
    quantity: number;
    /** Ignored on create — server computes final_price. */
    finalPrice?: number | undefined;
  }>;
}

export interface ThriftCustomerSalesRiskRto {
  kind: 'RTO';
  invoiceId: number;
  invoiceNumber: string;
  at: string;
  totalInvoiceAmount: number;
}

export interface ThriftCustomerSalesRiskReturn {
  kind: 'CUSTOMER_RETURN';
  returnId: number;
  returnNumber: string;
  invoiceId: number;
  invoiceNumber: string;
  at: string;
  refundAmount: number;
  lineCount: number;
  hasDamaged: boolean;
}

export interface ThriftCustomerSalesRisk {
  customerId: number | null;
  rtoCount: number;
  returnCount: number;
  rtos: ThriftCustomerSalesRiskRto[];
  returns: ThriftCustomerSalesRiskReturn[];
}

export interface ThriftSalesInvoiceListItem {
  id: number;
  invoiceNumber: string;
  saleChannel: ThriftSaleChannel;
  customerId: number | null;
  customerName: string | null;
  customerPhone: string | null;
  customerSecondaryPhone: string | null;
  customerAddress: string | null;
  customerAddressParts: ThriftCustomerAddressParts;
  date: string;
  paymentMethod: string;
  paymentStatus: string;
  deliveryStatus: ThriftDeliveryStatus | null;
  totalInvoiceAmount: number;
  courierAmount: number;
  courierPaidBy: ThriftCourierPaidBy | null;
  codExpected: number | null;
  codRemittedAmount: number | null;
  codRemittedAt: string | null;
  codRemittanceRef: string | null;
  /** Online COD advance collected at create; non-refundable. */
  advanceAmount: number;
  advanceNote: string | null;
  /** @deprecated Alias of courierAmount for older UI; prefer courierAmount. */
  courierCodAmount: number;
  /** @deprecated Historical only; create path no longer writes this. */
  otherExpenseAmount: number;
  createdBy: string;
  notes: string | null;
  itemCount: number;
  createdAt: string;
  status: string;
  revertedAt: string | null;
  revertedBy: string | null;
  revertReason: string | null;
  revertNotes: string | null;
  closeReason: string | null;
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

export type ThriftSalesRevertReason = 'RTO' | 'STAFF_MISTAKE' | 'RETURN';

function mapSaleChannel(value: unknown): ThriftSaleChannel {
  return value === 'ONLINE' ? 'ONLINE' : 'IN_STORE';
}

function mapCourierPaidBy(value: unknown): ThriftCourierPaidBy | null {
  return value === 'CUSTOMER' || value === 'SHOP' ? value : null;
}

function mapDeliveryStatus(value: unknown): ThriftDeliveryStatus | null {
  const s = String(value || '').toUpperCase();
  if (
    s === 'PENDING' ||
    s === 'READY' ||
    s === 'IN_TRANSIT' ||
    s === 'DELIVERED' ||
    s === 'RETURNED'
  ) {
    return s;
  }
  return null;
}

function mapAddressParts(raw: unknown): ThriftCustomerAddressParts {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const o = raw as Record<string, unknown>;
  const parts: ThriftCustomerAddressParts = {};
  if (typeof o.district === 'string' && o.district.trim()) parts.district = o.district.trim();
  if (typeof o.thana === 'string' && o.thana.trim()) parts.thana = o.thana.trim();
  if (typeof o.post_code === 'string' && o.post_code.trim()) parts.post_code = o.post_code.trim();
  return parts;
}

function mapInvoiceRow(row: any): Omit<ThriftSalesInvoiceListItem, 'itemCount'> {
  const courierAmount =
    Number(row.courier_amount ?? row.courier_cod_amount) || 0;
  return {
    id: row.id,
    invoiceNumber: row.invoice_number,
    saleChannel: mapSaleChannel(row.sale_channel),
    customerId: row.customer_id != null ? Number(row.customer_id) : null,
    customerName: row.customer_name ?? null,
    customerPhone: row.customer_phone ?? null,
    customerSecondaryPhone: row.customer_secondary_phone ?? null,
    customerAddress: row.customer_address ?? null,
    customerAddressParts: mapAddressParts(row.customer_address_parts),
    date: row.date,
    paymentMethod: row.payment_method,
    paymentStatus: row.payment_status,
    deliveryStatus: mapDeliveryStatus(row.delivery_status),
    totalInvoiceAmount: Number(row.total_invoice_amount) || 0,
    courierAmount,
    courierPaidBy: mapCourierPaidBy(row.courier_paid_by),
    codExpected:
      row.cod_expected != null && row.cod_expected !== ''
        ? Number(row.cod_expected) || 0
        : null,
    codRemittedAmount:
      row.cod_remitted_amount != null && row.cod_remitted_amount !== ''
        ? Number(row.cod_remitted_amount) || 0
        : null,
    codRemittedAt: row.cod_remitted_at ?? null,
    codRemittanceRef: row.cod_remittance_ref ?? null,
    advanceAmount: Number(row.advance_amount) || 0,
    advanceNote: row.advance_note ?? null,
    courierCodAmount: courierAmount,
    otherExpenseAmount: Number(row.other_expense_amount) || 0,
    createdBy: row.created_by || '',
    notes: row.notes ?? null,
    createdAt: row.created_at,
    status: row.status || 'ACTIVE',
    revertedAt: row.reverted_at ?? null,
    revertedBy: row.reverted_by ?? null,
    revertReason: row.revert_reason ?? null,
    revertNotes: row.revert_notes ?? null,
    closeReason: row.close_reason ?? null,
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
  paymentStatus?: string | null | undefined;
  status?: string | null | undefined;
  deliveryStatus?: string | null | undefined;
}

export type ThriftCodRemittanceOutcome = 'PAID' | 'KEEP_PENDING' | 'WRITTEN_OFF';

export interface RecordCodRemittanceInput {
  tenantId: number;
  invoiceId: number;
  remittedAmount: number;
  actor: string;
  remittedAt?: string | undefined;
  remittanceRef?: string | undefined;
  notes?: string | undefined;
  outcome?: ThriftCodRemittanceOutcome | undefined;
}

export interface RecordCodRemittanceResult {
  invoiceId: number;
  paymentStatus: string;
  codExpected: number | null;
  codRemittedAmount: number;
  outcome: string;
}

export type ThriftReturnItemCondition = 'SELLABLE' | 'DAMAGED';

export interface CreateSalesReturnInput {
  tenantId: number;
  invoiceId: number;
  items: Array<{
    invoiceItemId: number;
    quantity: number;
    condition: ThriftReturnItemCondition;
  }>;
  returnCourierAmount?: number | undefined;
  notes?: string | undefined;
  createdBy: string;
}

export interface CreateSalesReturnResult {
  returnId: number;
  returnNumber: string;
  invoiceId: number;
  refundAmount: number;
  returnCourierAmount: number;
  status: string;
  paymentStatus: string;
  closeReason: string | null;
}

export interface ThriftSalesReturnListItem {
  id: number;
  returnNumber: string;
  invoiceId: number;
  invoiceNumber: string;
  customerName: string | null;
  customerPhone: string | null;
  refundAmount: number;
  returnCourierAmount: number;
  status: string;
  notes: string | null;
  lineCount: number;
  hasDamaged: boolean;
  createdBy: string;
  createdAt: string;
}

export interface ListSalesReturnsParams {
  tenantId: number;
  page?: number | undefined;
  pageSize?: number | undefined;
  search?: string | undefined;
  dateFrom?: string | null | undefined;
  dateTo?: string | null | undefined;
  invoiceId?: number | null | undefined;
  hasDamaged?: boolean | null | undefined;
  skipCount?: boolean | undefined;
}

export interface ThriftSalesReturnListResult {
  data: ThriftSalesReturnListItem[];
  meta: {
    page: number;
    total: number | null;
    pageSize: number;
    totalPages: number | null;
    skipCount: boolean;
  };
}

export interface ThriftSalesReturnItemDetail {
  id: number;
  invoiceItemId: number;
  stockId: number;
  quantity: number;
  condition: ThriftReturnItemCondition;
  refundAmount: number;
  stockName: string | null;
  barcode: string | null;
}

export interface ThriftSalesReturnDetail {
  id: number;
  returnNumber: string;
  invoiceId: number;
  invoiceNumber: string;
  customerName: string | null;
  customerPhone: string | null;
  refundAmount: number;
  returnCourierAmount: number;
  status: string;
  notes: string | null;
  createdBy: string;
  createdAt: string;
  items: ThriftSalesReturnItemDetail[];
}

function mapReturnListRow(row: Record<string, unknown>): ThriftSalesReturnListItem {
  return {
    id: Number(row.id) || 0,
    returnNumber: String(row.return_number ?? ''),
    invoiceId: Number(row.invoice_id) || 0,
    invoiceNumber: String(row.invoice_number ?? ''),
    customerName: (row.customer_name as string | null) ?? null,
    customerPhone: (row.customer_phone as string | null) ?? null,
    refundAmount: Number(row.refund_amount) || 0,
    returnCourierAmount: Number(row.return_courier_amount) || 0,
    status: String(row.status ?? 'COMPLETED'),
    notes: (row.notes as string | null) ?? null,
    lineCount: Number(row.line_count) || 0,
    hasDamaged: Boolean(row.has_damaged),
    createdBy: String(row.created_by ?? ''),
    createdAt: String(row.created_at ?? ''),
  };
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
      p_payment_status: params.paymentStatus?.trim() || null,
      p_status: params.status?.trim() || null,
      p_delivery_status: params.deliveryStatus?.trim() || null,
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
        sale_channel,
        customer_id,
        customer_name,
        customer_phone,
        customer_secondary_phone,
        customer_address,
        customer_address_parts,
        date,
        payment_method,
        payment_status,
        delivery_status,
        total_invoice_amount,
        courier_amount,
        courier_paid_by,
        courier_cod_amount,
        other_expense_amount,
        cod_expected,
        cod_remitted_amount,
        cod_remitted_at,
        cod_remittance_ref,
        advance_amount,
        advance_note,
        created_by,
        notes,
        created_at,
        status,
        close_reason,
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
   * Advance Online parcel delivery_status. Does not change payment_status.
   * First DELIVERED writes PnL. DELIVERED→IN_TRANSIT deletes DELIVERED PnL.
   * RETURNED must go through revertSalesInvoice(RTO).
   */
  async updateDeliveryStatus(input: {
    tenantId: number;
    invoiceId: number;
    deliveryStatus: Exclude<ThriftDeliveryStatus, 'RETURNED'>;
    actor: string;
  }): Promise<{ id: number; deliveryStatus: ThriftDeliveryStatus; unchanged: boolean }> {
    const { data, error } = await supabase.rpc('update_thrift_sales_delivery_status', {
      p_tenant_id: input.tenantId,
      p_invoice_id: input.invoiceId,
      p_delivery_status: input.deliveryStatus,
      p_actor: input.actor,
    });

    if (error) throw error;

    const result = data as any;
    return {
      id: Number(result?.id ?? input.invoiceId),
      deliveryStatus: mapDeliveryStatus(result?.delivery_status) || input.deliveryStatus,
      unchanged: Boolean(result?.unchanged),
    };
  },

  /**
   * Record courier COD cash received. Updates payment fields only — no second REVENUE.
   */
  async recordCodRemittance(
    input: RecordCodRemittanceInput,
  ): Promise<RecordCodRemittanceResult> {
    const { data, error } = await supabase.rpc('record_thrift_cod_remittance', {
      p_tenant_id: input.tenantId,
      p_invoice_id: input.invoiceId,
      p_remitted_amount: input.remittedAmount,
      p_actor: input.actor,
      p_remitted_at: input.remittedAt || null,
      p_remittance_ref: input.remittanceRef?.trim() || null,
      p_notes: input.notes?.trim() || null,
      p_outcome: input.outcome || null,
    });

    if (error) throw error;

    const result = data as any;
    return {
      invoiceId: Number(result?.invoice_id ?? input.invoiceId),
      paymentStatus: String(result?.payment_status ?? ''),
      codExpected:
        result?.cod_expected != null && result.cod_expected !== ''
          ? Number(result.cod_expected) || 0
          : null,
      codRemittedAmount: Number(result?.cod_remitted_amount ?? input.remittedAmount) || 0,
      outcome: String(result?.outcome ?? input.outcome ?? ''),
    };
  },

  /**
   * Revert an ACTIVE invoice:
   * - RTO → soft-close Online refuse (legacy RETURN maps to RTO on server)
   * - STAFF_MISTAKE → hard-delete invoice/lines/ledger/PnL; restore stock; counter unchanged
   */
  async revertSalesInvoice(input: {
    tenantId: number;
    invoiceId: number;
    reason: ThriftSalesRevertReason;
    revertedBy: string;
    notes?: string | undefined;
    force?: boolean | undefined;
    returnCourierAmount?: number | undefined;
  }): Promise<{
    id: number;
    invoiceNumber: string;
    status: string;
    deleted: boolean;
    counterUnchanged?: boolean;
    closeReason?: string | null;
  }> {
    const { data, error } = await supabase.rpc('revert_thrift_sales_invoice', {
      p_tenant_id: input.tenantId,
      p_invoice_id: input.invoiceId,
      p_reason: input.reason === 'RETURN' ? 'RTO' : input.reason,
      p_reverted_by: input.revertedBy,
      p_notes: input.notes || null,
      p_force: input.force === true,
      p_return_courier_amount:
        input.reason === 'RTO' || input.reason === 'RETURN'
          ? Math.max(0, Number(input.returnCourierAmount) || 0)
          : 0,
    });

    if (error) throw error;

    const result = data as any;
    return {
      id: Number(result?.id ?? input.invoiceId),
      invoiceNumber: String(result?.invoice_number ?? ''),
      status: String(result?.status ?? ''),
      deleted: Boolean(result?.deleted),
      counterUnchanged: result?.counter_unchanged === true,
      closeReason: result?.close_reason != null ? String(result.close_reason) : null,
    };
  },

  /**
   * Create sales invoice via create_thrift_sales_invoice.
   * Offline: PAID + PnL DELIVERED. Online: COD_PENDING/PENDING, fees; no PnL yet.
   */
  async createSalesInvoice(input: CreateSalesInvoiceInput): Promise<{ id: number; invoiceNumber: string }> {
    const saleChannel = input.saleChannel || 'IN_STORE';
    const isOffline = saleChannel === 'IN_STORE';

    const courierAmount = isOffline
      ? 0
      : Math.max(0, Number(input.courierAmount ?? input.courierCodAmount) || 0);
    const packingAmount = isOffline
      ? 0
      : Math.max(0, Number(input.packingAmount) || 0);
    const codFeeAmount = isOffline
      ? 0
      : Math.max(0, Number(input.codFeeAmount) || 0);

    const courierPaidBy =
      !isOffline && courierAmount > 0 ? input.courierPaidBy || null : null;
    const packingPaidBy =
      !isOffline && packingAmount > 0 ? input.packingPaidBy || null : null;
    const codFeePaidBy =
      !isOffline && codFeeAmount > 0 ? input.codFeePaidBy || null : null;

    const advanceAmount = isOffline
      ? 0
      : Math.max(0, Number(input.advanceAmount) || 0);
    const advanceNote =
      !isOffline && advanceAmount > 0
        ? input.advanceNote?.trim() || null
        : null;

    const { data, error } = await supabase.rpc('create_thrift_sales_invoice', {
      p_tenant_id: input.tenantId,
      p_sale_channel: saleChannel,
      p_customer_name: input.customerName || null,
      p_customer_phone: input.customerPhone || null,
      p_customer_secondary_phone: input.customerSecondaryPhone || null,
      p_customer_address: input.customerAddress || null,
      p_customer_address_parts: input.customerAddressParts || {},
      p_customer_notes: input.customerNotes || null,
      p_date: input.date,
      p_notes: input.notes || null,
      p_created_by: input.createdBy,
      p_total_invoice_amount: input.totalInvoiceAmount,
      p_courier_amount: courierAmount,
      p_courier_paid_by: courierPaidBy,
      p_packing_amount: packingAmount,
      p_packing_paid_by: packingPaidBy,
      p_cod_fee_amount: codFeeAmount,
      p_cod_fee_paid_by: codFeePaidBy,
      p_courier_provider: isOffline
        ? null
        : input.courierProvider?.trim() || null,
      p_courier_provider_id: isOffline ? null : input.courierProviderId || null,
      p_meta: isOffline ? {} : input.meta || {},
      p_advance_amount: advanceAmount,
      p_advance_note: advanceNote,
      p_items: input.items.map((item) => ({
        stock_id: item.stockId,
        sell_price: item.sellPrice,
        discount_amount: item.discountAmount,
        quantity: item.quantity,
      })),
    } as any);

    if (error) throw error;
    if (!data) throw new Error('Failed to create sales invoice');

    const result = data as any;
    return {
      id: Number(result.id ?? result),
      invoiceNumber: String(result.invoice_number ?? ''),
    };
  },

  /**
   * RTO + post-pay return history for create-sale risk panel (online COD advance).
   */
  async getCustomerSalesRisk(
    tenantId: number,
    phone: string,
  ): Promise<ThriftCustomerSalesRisk> {
    const { data, error } = await supabase.rpc('get_thrift_customer_sales_risk', {
      p_tenant_id: tenantId,
      p_phone: phone,
    } as any);

    if (error) throw error;

    const row = (data || {}) as Record<string, unknown>;
    const rtosRaw = Array.isArray(row.rtos) ? row.rtos : [];
    const returnsRaw = Array.isArray(row.returns) ? row.returns : [];

    return {
      customerId: row.customer_id != null ? Number(row.customer_id) : null,
      rtoCount: Number(row.rto_count) || 0,
      returnCount: Number(row.return_count) || 0,
      rtos: rtosRaw.map((item: any) => ({
        kind: 'RTO' as const,
        invoiceId: Number(item.invoice_id),
        invoiceNumber: String(item.invoice_number ?? ''),
        at: String(item.at ?? ''),
        totalInvoiceAmount: Number(item.total_invoice_amount) || 0,
      })),
      returns: returnsRaw.map((item: any) => ({
        kind: 'CUSTOMER_RETURN' as const,
        returnId: Number(item.return_id),
        returnNumber: String(item.return_number ?? ''),
        invoiceId: Number(item.invoice_id),
        invoiceNumber: String(item.invoice_number ?? ''),
        at: String(item.at ?? ''),
        refundAmount: Number(item.refund_amount) || 0,
        lineCount: Number(item.line_count) || 0,
        hasDamaged: Boolean(item.has_damaged),
      })),
    };
  },

  /**
   * Search thrift_customers by phone/name for POS autofill (CRM-lite, no full CRM page).
   */
  async searchCustomers(tenantId: number, q: string): Promise<ThriftCustomerSearchItem[]> {
    const needle = q.trim().replace(/[%_(),]/g, ' ');
    if (!needle) return [];

    const digits = needle.replace(/\D/g, '');
    const orParts = [`phone.ilike.%${needle}%`, `name.ilike.%${needle}%`];
    if (digits) orParts.push(`phone_normalized.ilike.%${digits}%`);

    const { data, error } = await supabase
      .from('thrift_customers')
      .select('id, name, phone, phone_normalized, secondary_phone, address, address_parts, notes')
      .eq('tenant_id', tenantId)
      .or(orParts.join(','))
      .order('updated_at', { ascending: false })
      .limit(20);

    if (error) throw error;

    return (data || []).map((row: any) => ({
      id: Number(row.id),
      name: row.name ?? null,
      phone: row.phone ?? null,
      phoneNormalized: row.phone_normalized ?? null,
      secondaryPhone: row.secondary_phone ?? null,
      address: row.address ?? null,
      addressParts: mapAddressParts(row.address_parts),
      notes: row.notes ?? null,
    }));
  },

  /**
   * Search stocks for POS invoice picker via single RPC.
   * Default: AVAILABLE only. With customerPhone digits, also include matching RESERVED holds.
   * Landed cost computed server-side (compute_thrift_landed_unit_cost).
   */
  async searchAvailableStocks(
    tenantId: number,
    search?: string,
    customerPhone?: string | null,
  ): Promise<AvailableStockItem[]> {
    const needle = (search || '').trim();
    if (!needle) return [];

    const { data, error } = await supabase.rpc(
      'search_thrift_available_stocks_for_sale',
      {
        p_tenant_id: tenantId,
        p_search: needle,
        p_customer_phone: customerPhone?.trim() || null,
        p_limit: 50,
      },
    );

    if (error) throw error;

    const rows = Array.isArray(data) ? data : [];
    return rows.map((row: any) => ({
      id: Number(row.id),
      name: String(row.name || 'Unnamed Item'),
      barcode: String(row.barcode || 'NO-BARCODE'),
      availableQuantity: Math.max(0, Number(row.available_quantity) || 0),
      defaultSellPrice: Math.max(0, Number(row.default_sell_price) || 0),
      landedCost: Math.max(0, Number(row.landed_cost) || 0),
      category: String(row.category || 'Uncategorized'),
      status: String(row.status || 'AVAILABLE'),
      brandName: row.brand_name || undefined,
      type: row.type || undefined,
      color: row.color || undefined,
      size: row.size || undefined,
      condition: row.condition || undefined,
      section: row.section || undefined,
      shelfCode: row.shelf_code || undefined,
      boxName: row.box_name || undefined,
      imageUrl: row.image_url || undefined,
      shipmentId: Number(row.shipment_id) || 0,
      shipmentName: row.shipment_name || undefined,
      heldForPhone: row.held_for_phone ?? null,
      heldForName: row.held_for_name ?? null,
    }));
  },

  async createSalesReturn(input: CreateSalesReturnInput): Promise<CreateSalesReturnResult> {
    const { data, error } = await supabase.rpc('create_thrift_sales_return', {
      p_tenant_id: input.tenantId,
      p_invoice_id: input.invoiceId,
      p_items: input.items.map((item) => ({
        invoice_item_id: item.invoiceItemId,
        quantity: item.quantity,
        condition: item.condition,
      })),
      p_return_courier_amount: Math.max(0, Number(input.returnCourierAmount) || 0),
      p_notes: input.notes?.trim() || null,
      p_created_by: input.createdBy,
    });

    if (error) throw error;

    const result = data as Record<string, unknown>;
    return {
      returnId: Number(result?.return_id) || 0,
      returnNumber: String(result?.return_number ?? ''),
      invoiceId: Number(result?.invoice_id ?? input.invoiceId),
      refundAmount: Number(result?.refund_amount) || 0,
      returnCourierAmount: Number(result?.return_courier_amount) || 0,
      status: String(result?.status ?? ''),
      paymentStatus: String(result?.payment_status ?? ''),
      closeReason: result?.close_reason != null ? String(result.close_reason) : null,
    };
  },

  async listSalesReturnsPaginated(
    params: ListSalesReturnsParams,
  ): Promise<ThriftSalesReturnListResult> {
    const page = params.page ?? 1;
    const pageSize = params.pageSize ?? 20;

    const { data, error } = await supabase.rpc('list_thrift_sales_returns_paginated', {
      p_tenant_id: params.tenantId,
      p_page: page,
      p_page_size: pageSize,
      p_search: params.search?.trim() || null,
      p_date_from: params.dateFrom || null,
      p_date_to: params.dateTo || null,
      p_invoice_id: params.invoiceId ?? null,
      p_has_damaged: params.hasDamaged ?? null,
      p_skip_count: params.skipCount === true,
    });

    if (error) throw error;

    const raw = (data || {}) as { data?: unknown[]; meta?: Record<string, unknown> };
    const rows = Array.isArray(raw.data) ? raw.data : [];
    const meta = raw.meta || {};

    return {
      data: rows.map((row) => mapReturnListRow((row || {}) as Record<string, unknown>)),
      meta: {
        page: Number(meta.page) || page,
        total: meta.total == null ? null : Number(meta.total) || 0,
        pageSize: Number(meta.page_size) || pageSize,
        totalPages: meta.total_pages == null ? null : Number(meta.total_pages) || 0,
        skipCount: Boolean(meta.skip_count),
      },
    };
  },

  async getSalesReturn(
    tenantId: number,
    returnId: number,
  ): Promise<ThriftSalesReturnDetail | null> {
    const { data: header, error: headerError } = await supabase
      .from('thrift_sales_returns')
      .select(
        `
        id,
        return_number,
        invoice_id,
        refund_amount,
        return_courier_amount,
        status,
        notes,
        created_by,
        created_at,
        thrift_sales_invoices!inner (
          invoice_number,
          customer_name,
          customer_phone,
          tenant_id
        )
      `,
      )
      .eq('tenant_id', tenantId)
      .eq('id', returnId)
      .maybeSingle();

    if (headerError) throw headerError;
    if (!header) return null;

    const inv = (header as any).thrift_sales_invoices || {};

    const { data: items, error: itemsError } = await supabase
      .from('thrift_sales_return_items')
      .select(
        `
        id,
        invoice_item_id,
        stock_id,
        quantity,
        condition,
        refund_amount,
        thrift_stocks (
          name,
          barcode
        )
      `,
      )
      .eq('tenant_id', tenantId)
      .eq('return_id', returnId)
      .order('id', { ascending: true });

    if (itemsError) throw itemsError;

    return {
      id: Number((header as any).id) || returnId,
      returnNumber: String((header as any).return_number ?? ''),
      invoiceId: Number((header as any).invoice_id) || 0,
      invoiceNumber: String(inv.invoice_number ?? ''),
      customerName: inv.customer_name ?? null,
      customerPhone: inv.customer_phone ?? null,
      refundAmount: Number((header as any).refund_amount) || 0,
      returnCourierAmount: Number((header as any).return_courier_amount) || 0,
      status: String((header as any).status ?? 'COMPLETED'),
      notes: (header as any).notes ?? null,
      createdBy: String((header as any).created_by ?? ''),
      createdAt: String((header as any).created_at ?? ''),
      items: (items || []).map((row: any) => ({
        id: Number(row.id) || 0,
        invoiceItemId: Number(row.invoice_item_id) || 0,
        stockId: Number(row.stock_id) || 0,
        quantity: Number(row.quantity) || 1,
        condition: row.condition === 'DAMAGED' ? 'DAMAGED' : 'SELLABLE',
        refundAmount: Number(row.refund_amount) || 0,
        stockName: row.thrift_stocks?.name ?? null,
        barcode: row.thrift_stocks?.barcode ?? null,
      })),
    };
  },

  async listReturnedInvoiceItemIds(
    tenantId: number,
    invoiceId: number,
  ): Promise<number[]> {
    const { data, error } = await supabase
      .from('thrift_sales_return_items')
      .select('invoice_item_id, thrift_sales_returns!inner(invoice_id, tenant_id)')
      .eq('tenant_id', tenantId)
      .eq('thrift_sales_returns.invoice_id', invoiceId);

    if (error) throw error;

    return (data || [])
      .map((row: any) => Number(row.invoice_item_id) || 0)
      .filter((id: number) => id > 0);
  },
};





