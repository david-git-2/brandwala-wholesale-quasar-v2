import { supabase } from 'src/boot/supabase';
import type {
  PpOrderLine,
  PpPurchaseRequest,
  PpPurchaseRequestListItem,
  PpPurchaseRequestStaffListItem,
  PpStaffOrderLineUpdatePayload,
  PpSupplierOrderLineUpdatePayload,
} from '../types/ppPurchaseRequest';
import type {
  PpAppOrderLineListFilters,
  PpAppOrderLineStaffFilterOptions,
} from '../types/ppAppOrderLineFilters';
import { normalizePpOrderLinePlacementStatus } from '../utils/ppOrderLinePlacement';

function parseRequest(data: unknown): PpPurchaseRequest {
  if (data == null || typeof data !== 'object') {
    throw new Error('Invalid purchase request response.');
  }
  const row = data as Record<string, unknown>;
  const id = typeof row.id === 'number' ? row.id : Number(row.id);
  const status = typeof row.status === 'string' ? row.status : String(row.status ?? '');
  if (!Number.isFinite(id) || !status) {
    throw new Error('Invalid purchase request response.');
  }
  return { ...(data as PpPurchaseRequest), id, status } as PpPurchaseRequest;
}

export type PpPurchaseRequestPostResult = Pick<
  PpPurchaseRequest,
  'id' | 'status' | 'request_number' | 'bucket_description' | 'updated_at'
>;

function parsePostResult(data: unknown): PpPurchaseRequestPostResult {
  if (data == null || typeof data !== 'object') {
    throw new Error('Invalid post response.');
  }
  const row = data as Record<string, unknown>;
  const id = typeof row.id === 'number' ? row.id : Number(row.id);
  const status = typeof row.status === 'string' ? row.status : String(row.status ?? '');
  if (!Number.isFinite(id) || status !== 'requested') {
    throw new Error('Invalid post response.');
  }
  return {
    id,
    status: 'requested',
    request_number: typeof row.request_number === 'string' ? row.request_number : null,
    bucket_description:
      typeof row.bucket_description === 'string' ? row.bucket_description : null,
    updated_at: typeof row.updated_at === 'string' ? row.updated_at : '',
  };
}

function parseRequestList(data: unknown): PpPurchaseRequestListItem[] {
  const rows = Array.isArray(data) ? data : [];
  return rows.filter(
    (row): row is PpPurchaseRequestListItem =>
      row != null
      && typeof row === 'object'
      && typeof (row as PpPurchaseRequestListItem).id === 'number'
      && typeof (row as PpPurchaseRequestListItem).status === 'string',
  );
}

function parseStaffRequestList(data: unknown): PpPurchaseRequestStaffListItem[] {
  const rows = Array.isArray(data) ? data : [];
  return rows
    .map((row) => {
      if (row == null || typeof row !== 'object') return null;
      const r = row as Record<string, unknown>;
      const id = typeof r.id === 'number' ? r.id : Number(r.id);
      const peopleGroupId = typeof r.people_group_id === 'number'
        ? r.people_group_id
        : Number(r.people_group_id);
      const status = typeof r.status === 'string' ? r.status : String(r.status ?? '');
      const peopleGroupName = typeof r.people_group_name === 'string' ? r.people_group_name : '';
      if (!Number.isFinite(id) || !Number.isFinite(peopleGroupId) || !status) return null;
      const base = parseRequestList([row])[0];
      if (!base) return null;
      return {
        ...base,
        people_group_id: peopleGroupId,
        people_group_name: peopleGroupName,
      };
    })
    .filter((row): row is PpPurchaseRequestStaffListItem => row != null);
}

function parseLineRow(row: Record<string, unknown>): PpOrderLine | null {
  const id = typeof row.id === 'number' ? row.id : Number(row.id);
  if (!Number.isFinite(id) || typeof row.url !== 'string') return null;
  return {
    id,
    purchase_request_id: Number(row.purchase_request_id),
    pp_customer_group_id: Number(row.pp_customer_group_id),
    url: row.url,
    tracking_url: typeof row.tracking_url === 'string' ? row.tracking_url : null,
    needed_qty: Number(row.needed_qty),
    description: typeof row.description === 'string' ? row.description : null,
    product_name: typeof row.product_name === 'string' ? row.product_name : null,
    image_url: typeof row.image_url === 'string' ? row.image_url : null,
    unit_price: row.unit_price == null ? null : Number(row.unit_price),
    pp_supplier_group_id: row.pp_supplier_group_id == null ? null : Number(row.pp_supplier_group_id),
    shipment_id: row.shipment_id == null ? null : Number(row.shipment_id),
    shipment_status: typeof row.shipment_status === 'string' ? row.shipment_status : null,
    is_added_to_cart: Boolean(row.is_added_to_cart),
    added_to_cart_at: typeof row.added_to_cart_at === 'string' ? row.added_to_cart_at : null,
    placement_status: normalizePpOrderLinePlacementStatus(row.placement_status),
    placed_qty: row.placed_qty == null ? null : Number(row.placed_qty),
    received_qty: row.received_qty == null ? null : Number(row.received_qty),
    status: typeof row.status === 'string' ? (row.status as PpOrderLine['status']) : 'draft',
    created_at: typeof row.created_at === 'string' ? row.created_at : '',
    customer_group_name:
      typeof row.customer_group_name === 'string' ? row.customer_group_name : null,
    supplier_group_name:
      typeof row.supplier_group_name === 'string' ? row.supplier_group_name : null,
    request_number: typeof row.request_number === 'string' ? row.request_number : null,
    request_bucket_description:
      typeof row.request_bucket_description === 'string'
        ? row.request_bucket_description
        : null,
  };
}

function parseLines(data: unknown): PpOrderLine[] {
  const rows = Array.isArray(data) ? data : [];
  return rows
    .map((row) => (row != null && typeof row === 'object' ? parseLineRow(row as Record<string, unknown>) : null))
    .filter((line): line is PpOrderLine => line != null);
}

function parseStaffOrderLineFilterOptions(data: unknown): PpAppOrderLineStaffFilterOptions {
  const row = data != null && typeof data === 'object' ? (data as Record<string, unknown>) : {};
  const urlHosts = Array.isArray(row.url_hosts)
    ? row.url_hosts.filter((h): h is string => typeof h === 'string')
    : [];
  const placementStatuses = Array.isArray(row.placement_statuses)
    ? row.placement_statuses.map((s) => normalizePpOrderLinePlacementStatus(s))
    : [];
  const parseGroups = (raw: unknown) => {
    if (!Array.isArray(raw)) return [];
    return raw
      .map((item) => {
        if (item == null || typeof item !== 'object') return null;
        const g = item as Record<string, unknown>;
        const id = typeof g.id === 'number' ? g.id : Number(g.id);
        const name = typeof g.name === 'string' ? g.name : '';
        if (!Number.isFinite(id) || !name) return null;
        return { id, name };
      })
      .filter((g): g is { id: number; name: string } => g != null);
  };
  const shipments = Array.isArray(row.shipments)
    ? row.shipments
        .map((item) => {
          if (item == null || typeof item !== 'object') return null;
          const s = item as Record<string, unknown>;
          const id = typeof s.id === 'number' ? s.id : Number(s.id);
          const name = typeof s.name === 'string' ? s.name : '';
          const shipmentCode = typeof s.shipment_code === 'string' ? s.shipment_code : '';
          if (!Number.isFinite(id)) return null;
          return { id, name, shipment_code: shipmentCode };
        })
        .filter((s): s is { id: number; name: string; shipment_code: string } => s != null)
    : [];
  return {
    url_hosts: urlHosts,
    placement_statuses: placementStatuses,
    customer_groups: parseGroups(row.customer_groups),
    supplier_groups: parseGroups(row.supplier_groups),
    shipments,
  };
}

export const ppPurchaseRequestRepository = {
  async listLinesForCustomer(tenantId: number): Promise<PpOrderLine[]> {
    const { data, error } = await supabase.rpc('list_pp_order_lines_for_customer', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseLines(data);
  },

  async listLinesForSupplier(
    tenantId: number,
    peopleGroupMemberId: number,
  ): Promise<PpOrderLine[]> {
    const { data, error } = await supabase.rpc('list_pp_order_lines_for_supplier', {
      p_tenant_id: tenantId,
      p_people_group_member_id: peopleGroupMemberId,
    });
    if (error) throw error;
    return parseLines(data);
  },

  async listForCustomer(tenantId: number): Promise<PpPurchaseRequestListItem[]> {
    const { data, error } = await supabase.rpc('list_pp_purchase_requests_for_customer', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseRequestList(data);
  },

  async listForStaff(tenantId: number): Promise<PpPurchaseRequestStaffListItem[]> {
    const { data, error } = await supabase.rpc('list_pp_purchase_requests', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseStaffRequestList(data);
  },

  async listLinesForStaff(
    tenantId: number,
    filters?: PpAppOrderLineListFilters,
  ): Promise<PpOrderLine[]> {
    const { data, error } = await supabase.rpc('list_pp_order_lines', {
      p_tenant_id: tenantId,
      p_pp_customer_group_id: filters?.pp_customer_group_id ?? undefined,
      p_pp_supplier_group_id: filters?.pp_supplier_group_id ?? undefined,
      p_shipment_id: filters?.shipment_id ?? undefined,
      p_placement_statuses:
        filters?.placement_statuses?.length ? filters.placement_statuses : undefined,
      p_url_hosts: filters?.url_hosts?.length ? filters.url_hosts : undefined,
    });
    if (error) throw error;
    return parseLines(data);
  },

  async listStaffOrderLineFilterOptions(
    tenantId: number,
  ): Promise<PpAppOrderLineStaffFilterOptions> {
    const { data, error } = await supabase.rpc('list_pp_order_lines_staff_filter_options', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseStaffOrderLineFilterOptions(data);
  },

  async updateLineForSupplier(
    tenantId: number,
    peopleGroupMemberId: number,
    payload: PpSupplierOrderLineUpdatePayload,
  ): Promise<PpOrderLine> {
    const { data, error } = await supabase.rpc('update_pp_order_line_supplier', {
      p_tenant_id: tenantId,
      p_people_group_member_id: peopleGroupMemberId,
      p_line_id: payload.lineId,
      p_placed_qty: payload.placed_qty ?? undefined,
      p_placement_status: payload.placement_status ?? undefined,
    });
    if (error) throw error;
    const parsed = parseLineRow(data as Record<string, unknown>);
    if (!parsed) throw new Error('Invalid order line response.');
    return parsed;
  },

  async updateLineForStaff(
    tenantId: number,
    payload: PpStaffOrderLineUpdatePayload,
  ): Promise<PpOrderLine> {
    const { data, error } = await supabase.rpc('update_pp_order_line_staff', {
      p_tenant_id: tenantId,
      p_line_id: payload.lineId,
      p_url: payload.url,
      p_tracking_url: payload.tracking_url ?? null,
      p_needed_qty: payload.needed_qty,
      p_description: payload.description ?? undefined,
      p_product_name: payload.product_name ?? undefined,
      p_image_url: payload.image_url ?? undefined,
      p_unit_price: payload.unit_price ?? undefined,
      p_pp_supplier_group_id: payload.pp_supplier_group_id ?? undefined,
      p_shipment_id: payload.shipment_id ?? undefined,
      p_is_added_to_cart: payload.is_added_to_cart,
      p_placement_status: payload.placement_status,
      p_placed_qty: payload.placed_qty ?? undefined,
      p_received_qty: payload.received_qty ?? undefined,
    });
    if (error) throw error;
    const parsed = parseLineRow(data as Record<string, unknown>);
    if (!parsed) throw new Error('Invalid order line response.');
    return parsed;
  },

  async deleteLineForStaff(tenantId: number, lineId: number): Promise<void> {
    const { error } = await supabase.rpc('delete_pp_order_line_staff', {
      p_tenant_id: tenantId,
      p_line_id: lineId,
    });
    if (error) throw error;
  },

  async createDraft(tenantId: number): Promise<PpPurchaseRequest> {
    const { data, error } = await supabase.rpc('create_pp_purchase_request_draft', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseRequest(data);
  },

  async getRequest(tenantId: number, requestId: number): Promise<PpPurchaseRequest> {
    const { data, error } = await supabase.rpc('get_pp_purchase_request', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
    });
    if (error) throw error;
    return parseRequest(data);
  },

  async listLines(tenantId: number, requestId: number): Promise<PpOrderLine[]> {
    const { data, error } = await supabase.rpc('list_pp_order_lines_for_request', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
    });
    if (error) throw error;
    return parseLines(data);
  },

  async updateLine(
    tenantId: number,
    requestId: number,
    lineId: number,
    payload: { url: string; needed_qty: number; description?: string | null },
  ): Promise<PpOrderLine> {
    const { data, error } = await supabase.rpc('update_pp_order_line', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
      p_line_id: lineId,
      p_url: payload.url,
      p_needed_qty: payload.needed_qty,
      p_description: payload.description ?? undefined,
    });
    if (error) throw error;
    const parsed = parseLineRow(data as Record<string, unknown>);
    if (!parsed) throw new Error('Invalid order line response.');
    return parsed;
  },

  async deleteLine(tenantId: number, requestId: number, lineId: number): Promise<void> {
    const { error } = await supabase.rpc('delete_pp_order_line', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
      p_line_id: lineId,
    });
    if (error) throw error;
  },

  async addLine(
    tenantId: number,
    requestId: number,
    payload: { url: string; needed_qty: number; description?: string | null },
  ): Promise<PpOrderLine> {
    const { data, error } = await supabase.rpc('add_pp_order_line', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
      p_url: payload.url,
      p_needed_qty: payload.needed_qty,
      p_description: payload.description ?? undefined,
    });
    if (error) throw error;
    const parsed = parseLineRow(data as Record<string, unknown>);
    if (!parsed) throw new Error('Invalid order line response.');
    return parsed;
  },

  async updateInstructions(
    tenantId: number,
    requestId: number,
    bucketDescription: string,
  ): Promise<void> {
    const { error } = await supabase.rpc('update_pp_purchase_request_instructions', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
      p_bucket_description: bucketDescription,
    });
    if (error) throw error;
  },

  async postRequest(tenantId: number, requestId: number): Promise<PpPurchaseRequestPostResult> {
    const { data, error } = await supabase.rpc('post_pp_purchase_request', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
    });
    if (error) throw error;
    return parsePostResult(data);
  },

  async deleteDraft(tenantId: number, requestId: number): Promise<void> {
    const { error } = await supabase.rpc('delete_pp_purchase_request_draft', {
      p_tenant_id: tenantId,
      p_request_id: requestId,
    });
    if (error) throw error;
  },
};