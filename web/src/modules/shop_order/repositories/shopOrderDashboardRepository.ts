import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';

export type ShopOrderDashboardHour = {
  label: string;
  amount: number;
};

export type ShopOrderDashboardCourier = {
  name: string;
  count: number;
  shippedCount: number;
  readyCount: number;
};

export type ShopOrderDashboardPipelineRow = {
  status: string;
  count: number;
};

export type ShopOrderDashboardMetrics = {
  tenantId: number;
  todaySalesAmount: number;
  todayInvoiceCount: number;
  shippedCount: number;
  readyForPickupCount: number;
  needsQuoteCount: number;
  processingCount: number;
  dropshipSubmitted: number;
  dropshipProcessing: number;
  dropshipReady: number;
  hourly: ShopOrderDashboardHour[];
  couriers: ShopOrderDashboardCourier[];
  pipeline: ShopOrderDashboardPipelineRow[];
};

export const shopOrderDashboardRepository = {
  async getMetrics(tenantId: number): Promise<ShopOrderDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_shop_order_dashboard_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    const hourlyRaw = Array.isArray(raw.hourly) ? raw.hourly : [];
    const couriersRaw = Array.isArray(raw.couriers) ? raw.couriers : [];
    const pipelineRaw = Array.isArray(raw.pipeline) ? raw.pipeline : [];

    return {
      tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
      todaySalesAmount: asDashboardNumber(raw.today_sales_amount),
      todayInvoiceCount: asDashboardNumber(raw.today_invoice_count),
      shippedCount: asDashboardNumber(raw.shipped_count),
      readyForPickupCount: asDashboardNumber(raw.ready_for_pickup_count),
      needsQuoteCount: asDashboardNumber(raw.needs_quote_count),
      processingCount: asDashboardNumber(raw.processing_count),
      dropshipSubmitted: asDashboardNumber(raw.dropship_submitted),
      dropshipProcessing: asDashboardNumber(raw.dropship_processing),
      dropshipReady: asDashboardNumber(raw.dropship_ready),
      hourly: hourlyRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          label: typeof item.label === 'string' ? item.label.trim() : '',
          amount: asDashboardNumber(item.amount),
        };
      }),
      couriers: couriersRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          name: typeof item.name === 'string' ? item.name : 'Store pickup',
          count: asDashboardNumber(item.count),
          shippedCount: asDashboardNumber(item.shipped_count),
          readyCount: asDashboardNumber(item.ready_count),
        };
      }),
      pipeline: pipelineRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          status: typeof item.status === 'string' ? item.status : 'unknown',
          count: asDashboardNumber(item.count),
        };
      }),
    };
  },
};
