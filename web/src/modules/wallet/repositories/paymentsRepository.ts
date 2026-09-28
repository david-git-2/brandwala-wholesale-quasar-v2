import { supabase } from 'src/boot/supabase';
import type { Json } from 'src/types/database.types';
import type {
  CustomerGroupPaymentSummary,
  OpenInvoicePaymentItem,
  BatchPaymentPayload,
  BatchPaymentResult,
  CustomerGroupReceipt,
  UpdateInstrumentDetailsPayload,
  VoidCustomerReceiptPayload,
  VoidCustomerReceiptResult,
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
      p_instruments: (payload.instruments ?? []) as unknown as Json,
    });
    if (error) throw error;
    return data as unknown as BatchPaymentResult;
  },

  async listCustomerGroupReceipts(params: {
    tenantId: number;
    customerGroupId: number;
  }): Promise<CustomerGroupReceipt[]> {
    const { data, error } = await supabase.rpc('list_customer_group_receipts', {
      p_tenant_id: params.tenantId,
      p_customer_group_id: params.customerGroupId,
    });
    if (error) throw error;
    return (data as unknown as CustomerGroupReceipt[]) ?? [];
  },

  async updatePaymentInstrumentDetails(payload: UpdateInstrumentDetailsPayload): Promise<void> {
    const { error } = await supabase.rpc('update_payment_instrument_details', {
      p_tenant_id: payload.tenant_id,
      p_instrument_id: payload.instrument_id,
      p_reference: payload.reference ?? undefined,
      p_bd_bank_id: payload.bd_bank_id ?? undefined,
      p_cheque_number: payload.cheque_number ?? undefined,
      p_cheque_date: payload.cheque_date ?? undefined,
    });
    if (error) throw error;
  },

  async voidCustomerReceipt(payload: VoidCustomerReceiptPayload): Promise<VoidCustomerReceiptResult> {
    const { data, error } = await supabase.rpc('void_customer_receipt', {
      p_tenant_id: payload.tenant_id,
      p_payment_id: payload.payment_id,
      p_reason: payload.reason,
    });
    if (error) throw error;
    return data as unknown as VoidCustomerReceiptResult;
  },
};
