import { supabase } from 'src/boot/supabase';
import type { ShipmentReportDetailPayload } from '../types/shipmentReportDetailTypes';

const emptyQtySummary: ShipmentReportDetailPayload['qty_summary'] = {
  should_arrive: 0,
  arrived: 0,
  loss_at_shipment: 0,
  warehouse_stalled: 0,
  warehouse_remaining: 0,
  sold: 0,
  warehouse_value_bdt: 0,
};

const emptyProfitMatrix: ShipmentReportDetailPayload['profit_matrix'] = {
  total_cost_bdt: 0,
  total_cost_by_currency: [],
  total_sell_bdt: 0,
  receive_loss_bdt: 0,
  unpaid_total_bdt: 0,
  profit_loss_bdt: 0,
  profit_loss_pct: 0,
};

export const shipmentReportDetailRepository = {
  async fetchDetail(
    tenantId: number,
    shipmentId: number,
  ): Promise<ShipmentReportDetailPayload> {
    const { data, error } = await supabase.rpc('get_tenant_shipment_report_detail', {
      p_tenant_id: tenantId,
      p_shipment_id: shipmentId,
    });

    if (error) {
      console.error('[shipmentReportDetailRepository.fetchDetail error]:', error);
      throw error;
    }

    const payload = (data as unknown as ShipmentReportDetailPayload | null) ?? null;

    return {
      header: payload?.header ?? ({} as ShipmentReportDetailPayload['header']),
      pnl: payload?.pnl ?? null,
      qty_summary: payload?.qty_summary ?? emptyQtySummary,
      cost_buckets: payload?.cost_buckets ?? [],
      sell_lines: payload?.sell_lines ?? [],
      profit_matrix: payload?.profit_matrix ?? emptyProfitMatrix,
      unpaid_customers: payload?.unpaid_customers ?? [],
      ap_bills: payload?.ap_bills ?? [],
      ap_totals_by_currency: payload?.ap_totals_by_currency ?? [],
      customer_bills: payload?.customer_bills ?? [],
      customer_attributed_revenue_bdt: payload?.customer_attributed_revenue_bdt ?? 0,
      exchange_rates: payload?.exchange_rates ?? null,
    };
  },
};
