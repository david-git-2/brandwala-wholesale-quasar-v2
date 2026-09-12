import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';

export type ProcurementDashboardGrade = {
  name: string;
  qty: number;
};

export type ProcurementDashboardPipelineRow = {
  status: string;
  count: number;
};

export type ProcurementDashboardLocationRow = {
  name: string;
  qty: number;
};

export type ProcurementDashboardMetrics = {
  tenantId: number;
  sellableQty: number;
  heldQty: number;
  unsellableQty: number;
  totalQty: number;
  sellablePct: number;
  sellableValueBdt: number;
  inTransitCount: number;
  draftCount: number;
  receivedCount: number;
  grades: ProcurementDashboardGrade[];
  pipeline: ProcurementDashboardPipelineRow[];
  locations: ProcurementDashboardLocationRow[];
};

const empty = (tenantId: number): ProcurementDashboardMetrics => ({
  tenantId,
  sellableQty: 0,
  heldQty: 0,
  unsellableQty: 0,
  totalQty: 0,
  sellablePct: 0,
  sellableValueBdt: 0,
  inTransitCount: 0,
  draftCount: 0,
  receivedCount: 0,
  grades: [],
  pipeline: [],
  locations: [],
});

export const procurementDashboardRepository = {
  async getMetrics(tenantId: number): Promise<ProcurementDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_procurement_dashboard_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    const gradesRaw = Array.isArray(raw.grades) ? raw.grades : [];
    const pipelineRaw = Array.isArray(raw.pipeline) ? raw.pipeline : [];
    const locationsRaw = Array.isArray(raw.locations) ? raw.locations : [];

    return {
      tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
      sellableQty: asDashboardNumber(raw.sellable_qty),
      heldQty: asDashboardNumber(raw.held_qty),
      unsellableQty: asDashboardNumber(raw.unsellable_qty),
      totalQty: asDashboardNumber(raw.total_qty),
      sellablePct: asDashboardNumber(raw.sellable_pct),
      sellableValueBdt: asDashboardNumber(raw.sellable_value_bdt),
      inTransitCount: asDashboardNumber(raw.in_transit_count),
      draftCount: asDashboardNumber(raw.draft_count),
      receivedCount: asDashboardNumber(raw.received_count),
      grades: gradesRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          name: typeof item.name === 'string' ? item.name : 'Ungraded',
          qty: asDashboardNumber(item.qty),
        };
      }),
      pipeline: pipelineRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          status: typeof item.status === 'string' ? item.status : 'unknown',
          count: asDashboardNumber(item.count),
        };
      }),
      locations: locationsRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          name: typeof item.name === 'string' ? item.name : 'Unlocated',
          qty: asDashboardNumber(item.qty),
        };
      }),
    };
  },

  empty,
};
