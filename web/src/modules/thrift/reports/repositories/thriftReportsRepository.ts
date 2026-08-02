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

function num(v: unknown): number {
  return Number(v) || 0;
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
};
