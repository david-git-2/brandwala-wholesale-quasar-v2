import { supabase } from 'src/boot/supabase';
import type {
  ShipmentProfitReportPayload,
  ShipmentProfitReportQueryParams,
} from '../types/shipmentProfitTypes';

export const shipmentProfitRepository = {
  /**
   * Fetch consolidated batch shipment profit, landed cost, COGS, realized gross profit, remaining stock valuation and damage reporting.
   */
  async fetchShipmentProfitReport(
    params: ShipmentProfitReportQueryParams,
  ): Promise<ShipmentProfitReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_shipment_profit_report', {
      p_tenant_id: params.tenantId,
      p_shipment_id: params.shipmentId ?? undefined,
      p_search: params.search && params.search.trim() !== '' ? params.search.trim() : undefined,
      p_start_date: params.startDate ?? undefined,
      p_end_date: params.endDate ?? undefined,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 20,
    });

    if (error) {
      console.error('[shipmentProfitRepository.fetchShipmentProfitReport error]:', error);
      throw error;
    }

    const payload = (data as unknown as ShipmentProfitReportPayload | null) ?? null;
    return {
      summary: payload?.summary || {
        total_inbound_units: 0,
        total_landed_cost: 0,
        total_net_sold_units: 0,
        total_gross_sold_revenue: 0,
        total_cogs: 0,
        total_realized_gross_profit: 0,
        overall_realized_gp_margin_pct: 0,
        total_unsold_stock_value: 0,
        total_damage_loss_value: 0,
        total_shipments_count: 0,
      },
      shipments: payload?.shipments || [],
      meta: payload?.meta || {
        total: 0,
        page: params.page ?? 1,
        page_size: params.pageSize ?? 20,
        total_pages: 1,
      },
    };
  },

  /**
   * Export shipment profit report rows to CSV.
   */
  exportReportToCsv(payload: ShipmentProfitReportPayload) {
    const headers = [
      'Shipment ID',
      'Shipment Name',
      'Status',
      'Created Date',
      'Inbound Qty',
      'Total Landed Cost (BDT)',
      'Sold Qty',
      'Gross Sold Revenue (BDT)',
      'COGS (BDT)',
      'Realized Gross Profit (BDT)',
      'GP Margin (%)',
      'Batch Sold (%)',
      'Unsold Stock Qty',
      'Unsold Stock Value (BDT)',
      'Damaged Qty',
      'Damage Loss Value (BDT)',
    ];

    const rows = payload.shipments.map((s) => [
      s.shipment_id,
      `"${(s.shipment_name || '').replace(/"/g, '""')}"`,
      s.shipment_status,
      s.created_at ? new Date(s.created_at).toLocaleDateString() : '',
      s.inbound_quantity,
      s.total_landed_cost,
      s.net_sold_quantity,
      s.gross_sold_revenue,
      s.cogs_amount,
      s.realized_gross_profit,
      s.realized_gp_margin_pct,
      s.batch_sold_pct,
      s.sellable_stock_qty,
      s.unsold_stock_value,
      s.damaged_stock_qty,
      s.damage_loss_value,
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute(
      'download',
      `shipment_profit_report_${new Date().toISOString().slice(0, 10)}.csv`,
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  },
};
