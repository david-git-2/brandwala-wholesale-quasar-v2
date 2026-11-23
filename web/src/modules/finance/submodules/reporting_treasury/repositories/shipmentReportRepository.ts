import { supabase } from 'src/boot/supabase';
import type { ShipmentReportListPageMeta, ShipmentReportListRow } from '../types/shipmentReportTypes';

const WORKSPACE_PAGE_SIZE = 100;

type WorkspaceRpcRow = {
  id: number;
  name: string;
  tenant_shipment_id?: number | null;
  shipment_no?: string | null;
  status: string;
  created_at: string;
  vendor_name?: string | null;
  type?: string | null;
};

function mapRow(row: WorkspaceRpcRow): ShipmentReportListRow {
  return {
    id: row.id,
    tenant_shipment_id: row.tenant_shipment_id ?? null,
    shipment_no: row.shipment_no ?? null,
    name: row.name,
    status: row.status,
    created_at: row.created_at,
    vendor_name: row.vendor_name ?? null,
    type: row.type ?? null,
  };
}

export const shipmentReportRepository = {
  async fetchWorkspacePage(
    tenantId: number,
    options: {
      cursor?: number | null;
      search?: string | null;
      pageSize?: number;
    } = {},
  ): Promise<{ data: ShipmentReportListRow[]; meta: ShipmentReportListPageMeta }> {
    const { data, error } = await supabase.rpc('list_inbound_shipments_workspace', {
      p_tenant_id: tenantId,
      p_page_size: options.pageSize ?? WORKSPACE_PAGE_SIZE,
      p_cursor: options.cursor ?? null,
      p_search: options.search?.trim() ? options.search.trim() : null,
      p_status: null,
      p_is_archived: false,
      p_vendor_id: null,
      p_cargo_company_id: null,
      p_include_reference_data: false,
    });

    if (error) {
      console.error('[shipmentReportRepository.fetchWorkspacePage error]:', error);
      throw error;
    }

    const payload = data as {
      data?: WorkspaceRpcRow[];
      meta?: { next_cursor?: number | null; has_more?: boolean };
    };

    return {
      data: (payload.data ?? []).map(mapRow),
      meta: {
        nextCursor: payload.meta?.next_cursor ?? null,
        hasMore: payload.meta?.has_more === true,
      },
    };
  },

  async fetchAllActiveShipments(
    tenantId: number,
    search: string | null,
  ): Promise<ShipmentReportListRow[]> {
    const rows: ShipmentReportListRow[] = [];
    let cursor: number | null = null;
    let hasMore = true;

    while (hasMore) {
      const page = await shipmentReportRepository.fetchWorkspacePage(tenantId, {
        cursor,
        search,
      });
      rows.push(...page.data);
      hasMore = page.meta.hasMore;
      cursor = page.meta.nextCursor;
      if (!hasMore || page.data.length === 0) {
        break;
      }
    }

    return rows;
  },
};
