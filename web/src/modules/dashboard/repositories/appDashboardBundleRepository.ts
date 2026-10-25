import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';
import type { ProcurementDashboardMetrics } from 'src/modules/procurement_stock/repositories/procurementDashboardRepository';
import { procurementDashboardRepository } from 'src/modules/procurement_stock/repositories/procurementDashboardRepository';
import type { ShopOrderDashboardMetrics } from 'src/modules/shop_order/repositories/shopOrderDashboardRepository';
import type { InvestorCapitalDashboardMetrics } from 'src/modules/investor_capital/repositories/investorCapitalDashboardRepository';

import type { AppDashboardBundle, DashboardChildTenantRef } from '../types/appDashboardBundle';

const mapProcurement = (
  tenantId: number,
  raw: Record<string, unknown> | null,
): ProcurementDashboardMetrics | null => {
  if (!raw) return null;
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
};

const mapShopOrder = (tenantId: number, raw: Record<string, unknown> | null): ShopOrderDashboardMetrics | null => {
  if (!raw) return null;
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
};

const mapInvestor = (
  tenantId: number,
  raw: Record<string, unknown> | null,
): InvestorCapitalDashboardMetrics | null => {
  if (!raw) return null;
  const containersRaw = Array.isArray(raw.open_containers) ? raw.open_containers : [];
  return {
    tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
    activePoolAmount: asDashboardNumber(raw.active_pool_amount),
    deployedAmount: asDashboardNumber(raw.deployed_amount),
    deployedThisMonth: asDashboardNumber(raw.deployed_this_month),
    dueToInvestors: asDashboardNumber(raw.due_to_investors),
    returnedAmount: asDashboardNumber(raw.returned_amount),
    openContainerCount: asDashboardNumber(raw.open_container_count),
    openContainers: containersRaw.map((row) => {
      const item = row as Record<string, unknown>;
      return {
        name: typeof item.name === 'string' ? item.name : 'Container',
        allocatedCost: asDashboardNumber(item.allocated_cost),
      };
    }),
  };
};

const mapChildRefs = (raw: unknown): DashboardChildTenantRef[] => {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((row) => {
      const item = row as Record<string, unknown>;
      const id = asDashboardNumber(item.id);
      const parentId = asDashboardNumber(item.parent_id);
      if (!id || !parentId) return null;
      return {
        id,
        parent_id: parentId,
        name: typeof item.name === 'string' ? item.name : `Tenant #${id}`,
      };
    })
    .filter((row): row is DashboardChildTenantRef => row !== null);
};

const emptyBundle = (): AppDashboardBundle => ({
  refreshedAt: null,
  procurement: null,
  shopOrder: null,
  investorCapital: null,
  childTenantRefs: [],
});

export const appDashboardBundleRepository = {
  empty: emptyBundle,

  async fetchBundle(
    tenantId: number,
    parentTenantIds: number[],
  ): Promise<AppDashboardBundle> {
    const { data, error } = await supabase.rpc('get_app_dashboard_bundle', {
      p_tenant_id: tenantId,
      p_parent_tenant_ids: parentTenantIds.length ? parentTenantIds : null,
    });

    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    const refreshedRaw = raw.refreshed_at;
    const refreshedAt =
      typeof refreshedRaw === 'string'
        ? refreshedRaw
        : refreshedRaw != null
          ? String(refreshedRaw)
          : new Date().toISOString();

    return {
      refreshedAt,
      procurement: mapProcurement(
        tenantId,
        (raw.procurement as Record<string, unknown> | null) ?? null,
      ),
      shopOrder: mapShopOrder(tenantId, (raw.shop_order as Record<string, unknown> | null) ?? null),
      investorCapital: mapInvestor(
        tenantId,
        (raw.investor_capital as Record<string, unknown> | null) ?? null,
      ),
      childTenantRefs: mapChildRefs(raw.child_tenant_refs),
    };
  },

  emptyProcurement: procurementDashboardRepository.empty,
};
