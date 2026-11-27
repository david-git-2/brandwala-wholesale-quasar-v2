import { supabase } from 'src/boot/supabase';
import type {
  CustomerReportHeader,
  CustomerReportListPayload,
  CustomerReportSectionKind,
  CustomerReportSectionPayload,
} from '../types/customersReportTypes';

function assertSuccess<T extends { success?: boolean; error?: string }>(
  payload: T | null,
  fallback: string,
): T {
  if (!payload?.success) {
    throw new Error(payload?.error || fallback);
  }
  return payload;
}

export const customersReportRepository = {
  async listCustomers(params: {
    tenantId: number;
    search?: string | null;
    limit?: number;
    cursor?: string | null;
  }): Promise<CustomerReportListPayload> {
    const { data, error } = await supabase.rpc('list_customers_report', {
      p_tenant_id: params.tenantId,
      p_search: params.search?.trim() || undefined,
      p_limit: params.limit ?? 30,
      p_cursor: params.cursor ?? undefined,
    });
    if (error) throw error;
    const payload = (data ?? {}) as CustomerReportListPayload;
    return assertSuccess(payload, 'Could not load customers.');
  },

  async fetchHeader(tenantId: number, customerGroupId: number): Promise<CustomerReportHeader> {
    const { data, error } = await supabase.rpc('get_customer_report_header', {
      p_tenant_id: tenantId,
      p_customer_group_id: customerGroupId,
    });
    if (error) throw error;
    const payload = (data ?? {}) as CustomerReportHeader;
    return assertSuccess(payload, 'Could not load customer report.');
  },

  async fetchSection(params: {
    tenantId: number;
    customerGroupId: number;
    kind: CustomerReportSectionKind;
    limit?: number;
    cursor?: string | null;
  }): Promise<CustomerReportSectionPayload> {
    const { data, error } = await supabase.rpc('list_customer_report_section', {
      p_tenant_id: params.tenantId,
      p_customer_group_id: params.customerGroupId,
      p_kind: params.kind,
      p_limit: params.limit ?? 30,
      p_cursor: params.cursor ?? undefined,
    });
    if (error) throw error;
    const payload = (data ?? {}) as CustomerReportSectionPayload;
    return assertSuccess(payload, 'Could not load customer section.');
  },
};