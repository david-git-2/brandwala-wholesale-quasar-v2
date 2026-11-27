import { supabase } from 'src/boot/supabase';
import type { PpOrderLine, PpPurchaseRequest, PpPurchaseRequestListItem } from '../types/ppPurchaseRequest';

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
  if (!Number.isFinite(id) || status !== 'post') {
    throw new Error('Invalid post response.');
  }
  return {
    id,
    status: 'post',
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

function parseLines(data: unknown): PpOrderLine[] {
  const rows = Array.isArray(data) ? data : [];
  return rows.filter(
    (row): row is PpOrderLine =>
      row != null
      && typeof row === 'object'
      && typeof (row as PpOrderLine).id === 'number'
      && typeof (row as PpOrderLine).url === 'string',
  );
}

export const ppPurchaseRequestRepository = {
  async listForCustomer(tenantId: number): Promise<PpPurchaseRequestListItem[]> {
    const { data, error } = await supabase.rpc('list_pp_purchase_requests_for_customer', {
      p_tenant_id: tenantId,
    });
    if (error) throw error;
    return parseRequestList(data);
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
    return data as PpOrderLine;
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
    return data as PpOrderLine;
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