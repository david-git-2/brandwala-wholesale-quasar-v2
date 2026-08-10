import { supabase } from 'src/boot/supabase';
import { thriftShipmentRepository } from '../../shipment/repositories/thriftShipmentRepository';
import type { ThriftShipment } from '../../shipment/types';

export interface ThriftShipmentReportSummary {
  unitsSold: number;
  grossSales: number;
  discounts: number;
  netRevenue: number;
  cogs: number;
  netProfit: number;
  marginPct: number;
}

export interface ThriftShipmentReportLine {
  id: number;
  invoiceId: number;
  invoiceNumber: string;
  invoiceDate: string;
  stockId: number;
  stockName: string | null;
  barcode: string | null;
  quantity: number;
  sellPrice: number;
  discountAmount: number;
  finalPrice: number;
  landedUnitCostAtSale: number;
  netProfit: number;
}

export interface ThriftShipmentSalesReport {
  shipment: {
    id: number;
    name: string;
    createdAt: string;
    updatedAt: string;
  };
  summary: ThriftShipmentReportSummary;
  lines: ThriftShipmentReportLine[];
}

export interface ThriftPeriodSalesReportSummary {
  invoiceCount: number;
  unitsSold: number;
  netRevenue: number;
  cogs: number;
  lineProfit: number;
  courierCodAmount: number;
  otherExpenseAmount: number;
  totalFees: number;
  netAfterFees: number;
  refundCount: number;
  refundAmount: number;
}

export interface ThriftPeriodSalesChannelRow extends ThriftPeriodSalesReportSummary {
  saleChannel: string;
}

export interface ThriftCodOutstanding {
  invoiceCount: number;
  codExpectedTotal: number;
  codRemittedTotal: number;
}

export interface ThriftPeriodSalesReport {
  dateFrom: string;
  dateTo: string;
  saleChannel: string | null;
  summary: ThriftPeriodSalesReportSummary;
  byChannel: ThriftPeriodSalesChannelRow[];
  codOutstanding: ThriftCodOutstanding;
}

export interface ThriftDashboardMetrics {
  itemsAddedToday: number;
  totalItems: number;
  availableItems: number;
  soldItems: number;
  codPendingCount: number;
  codExpectedTotal: number;
  activeInvoicesToday: number;
}

function num(v: unknown): number {
  return Number(v) || 0;
}

function mapPeriodSummary(raw: Record<string, unknown>): ThriftPeriodSalesReportSummary {
  return {
    invoiceCount: num(raw.invoice_count),
    unitsSold: num(raw.units_sold),
    netRevenue: num(raw.net_revenue),
    cogs: num(raw.cogs),
    lineProfit: num(raw.line_profit),
    courierCodAmount: num(raw.courier_cod_amount),
    otherExpenseAmount: num(raw.other_expense_amount),
    totalFees: num(raw.total_fees),
    netAfterFees: num(raw.net_after_fees),
    refundCount: num(raw.refund_count),
    refundAmount: num(raw.refund_amount),
  };
}

export const thriftReportsRepository = {
  async listShipments(tenantId: number): Promise<ThriftShipment[]> {
    return thriftShipmentRepository.fetchShipments(tenantId);
  },

  async getShipmentSalesReport(
    tenantId: number,
    shipmentId: number,
  ): Promise<ThriftShipmentSalesReport> {
    const { data, error } = await supabase.rpc('get_thrift_shipment_sales_report', {
      p_tenant_id: tenantId,
      p_shipment_id: shipmentId,
    });
    if (error) throw error;

    const raw = (data || {}) as Record<string, any>;
    const shipment = raw.shipment || {};
    const summary = raw.summary || {};
    const lines = Array.isArray(raw.lines) ? raw.lines : [];

    return {
      shipment: {
        id: Number(shipment.id) || shipmentId,
        name: shipment.name || 'Unnamed Shipment',
        createdAt: shipment.created_at || '',
        updatedAt: shipment.updated_at || '',
      },
      summary: {
        unitsSold: num(summary.units_sold),
        grossSales: num(summary.gross_sales),
        discounts: num(summary.discounts),
        netRevenue: num(summary.net_revenue),
        cogs: num(summary.cogs),
        netProfit: num(summary.net_profit),
        marginPct: num(summary.margin_pct),
      },
      lines: lines.map((row: any) => ({
        id: Number(row.id),
        invoiceId: Number(row.invoice_id),
        invoiceNumber: row.invoice_number || '',
        invoiceDate: row.invoice_date || '',
        stockId: Number(row.stock_id),
        stockName: row.stock_name ?? null,
        barcode: row.barcode ?? null,
        quantity: num(row.quantity),
        sellPrice: num(row.sell_price),
        discountAmount: num(row.discount_amount),
        finalPrice: num(row.final_price),
        landedUnitCostAtSale: num(row.landed_unit_cost_at_sale),
        netProfit: num(row.net_profit),
      })),
    };
  },

  async getSalesReport(input: {
    tenantId: number;
    dateFrom: string;
    dateTo: string;
    saleChannel?: 'IN_STORE' | 'ONLINE' | null;
  }): Promise<ThriftPeriodSalesReport> {
    const { data, error } = await supabase.rpc('get_thrift_sales_report', {
      p_tenant_id: input.tenantId,
      p_date_from: input.dateFrom,
      p_date_to: input.dateTo,
      p_sale_channel: input.saleChannel || null,
    });
    if (error) throw error;

    const raw = (data || {}) as Record<string, any>;
    const summary = (raw.summary || {}) as Record<string, unknown>;
    const byChannel = Array.isArray(raw.by_channel) ? raw.by_channel : [];
    const codOutstanding = (raw.cod_outstanding || {}) as Record<string, unknown>;

    return {
      dateFrom: raw.date_from || input.dateFrom,
      dateTo: raw.date_to || input.dateTo,
      saleChannel: raw.sale_channel ?? null,
      summary: {
        ...mapPeriodSummary(summary),
        refundCount: num(summary.refund_count),
        refundAmount: num(summary.refund_amount),
      },
      byChannel: byChannel.map((row: Record<string, unknown>) => ({
        saleChannel: typeof row.sale_channel === 'string' ? row.sale_channel : 'IN_STORE',
        ...mapPeriodSummary(row),
        refundCount: 0,
        refundAmount: 0,
      })),
      codOutstanding: {
        invoiceCount: num(codOutstanding.invoice_count),
        codExpectedTotal: num(codOutstanding.cod_expected_total),
        codRemittedTotal: num(codOutstanding.cod_remitted_total),
      },
    };
  },

  async getDashboardMetrics(tenantId: number): Promise<ThriftDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_thrift_dashboard_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;

    const raw = (data || {}) as Record<string, unknown>;
    return {
      itemsAddedToday: num(raw.items_added_today),
      totalItems: num(raw.total_items),
      availableItems: num(raw.available_items),
      soldItems: num(raw.sold_items),
      codPendingCount: num(raw.cod_pending_count),
      codExpectedTotal: num(raw.cod_expected_total),
      activeInvoicesToday: num(raw.active_invoices_today),
    };
  },
};
