import { supabase } from 'src/boot/supabase';
import type { Json } from 'src/types/database.types';
import type {
  CustomerGroupPaymentSummary,
  OpenInvoicePaymentItem,
  BatchPaymentPayload,
  BatchPaymentResult,
} from '../types/paymentsTypes';

export const paymentsRepository = {
  async listCustomerGroupsPaymentSummary(params: {
    tenantId: number;
    search?: string | null;
    limit?: number;
    offset?: number;
  }): Promise<CustomerGroupPaymentSummary[]> {
    const { data, error } = await supabase.rpc('list_customer_groups_payment_summary', {
      p_tenant_id: params.tenantId,
      p_search: params.search?.trim() || undefined,
      p_limit: params.limit ?? 50,
      p_offset: params.offset ?? 0,
    });
    if (error) throw error;
    return (data as unknown as CustomerGroupPaymentSummary[]) ?? [];
  },

  async listOpenInvoicesForPayment(params: {
    tenantId: number;
    customerGroupId?: number | null;
    search?: string | null;
    limit?: number;
    offset?: number;
  }): Promise<OpenInvoicePaymentItem[]> {
    const { data, error } = await supabase.rpc('list_open_invoices_for_payment', {
      p_tenant_id: params.tenantId,
      p_customer_group_id: params.customerGroupId ?? undefined,
      p_search: params.search?.trim() || undefined,
      p_limit: params.limit ?? 50,
      p_offset: params.offset ?? 0,
    });
    if (error) throw error;
    return (data as unknown as OpenInvoicePaymentItem[]) ?? [];
  },

  async recordBatchCustomerPayment(payload: BatchPaymentPayload): Promise<BatchPaymentResult> {
    const { data, error } = await supabase.rpc('record_batch_customer_payment', {
      p_tenant_id: payload.tenant_id,
      p_customer_group_id: payload.customer_group_id ?? undefined,
      p_billing_profile_id: payload.billing_profile_id ?? undefined,
      p_amount: payload.amount,
      p_payment_date: payload.payment_date ?? new Date().toISOString().split('T')[0],
      p_method: payload.method ?? 'bank_transfer',
      p_reference: payload.reference ?? undefined,
      p_note: payload.note ?? undefined,
      p_allocations: payload.allocations as unknown as Json,
      p_write_offs: payload.write_offs as unknown as Json,
    });
    if (error) throw error;
    return data as unknown as BatchPaymentResult;
  },
};
