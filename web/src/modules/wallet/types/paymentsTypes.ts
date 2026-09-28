export interface CustomerGroupPaymentSummary {
  id: number;
  name: string;
  account_code: string;
  phone: string;
  branches: string[];
  open_invoice_count: number;
  total_invoiced: number;
  total_paid: number;
  total_written_off: number;
  total_due: number;
  last_payment_date: string | null;
}

export interface OpenInvoicePaymentItem {
  id: number;
  invoice_no: string;
  invoice_type: string;
  customer_group_id: number | null;
  customer_group_name: string;
  branch_name: string;
  invoice_date: string;
  due_date: string | null;
  total_amount: number;
  paid_amount: number;
  written_off_amount: number;
  due_amount: number;
  payment_status: string;

  // Frontend allocation working states
  allocated_amount?: number;
  is_write_off_enabled?: boolean;
  written_off_amount_input?: number;
  written_off_reason?: string;
}

export interface PaymentAllocationItem {
  invoice_id: number;
  amount: number;
}

export interface InvoiceWriteOffItem {
  invoice_id: number;
  amount: number;
  reason: string;
  note?: string | null;
}

export interface BatchPaymentPayload {
  tenant_id: number;
  customer_group_id?: number | null;
  billing_profile_id?: number | null;
  amount: number;
  payment_date?: string;
  method?: string;
  reference?: string | null;
  note?: string | null;
  instruments?: Array<{
    payment_method_code: string;
    amount: number;
    reference?: string | null;
    bd_bank_id?: number | null;
    cheque_number?: string | null;
    cheque_date?: string | null;
  }>;
  allocations: PaymentAllocationItem[];
  write_offs: InvoiceWriteOffItem[];
}

export interface BatchPaymentResult {
  payment_id: number;
  total_amount: number;
  total_allocated: number;
  total_written_off: number;
  unallocated_amount: number;
  payment_date: string;
  reference?: string | null;
}

export interface CustomerReceiptInstrument {
  id: number;
  payment_method_code: string;
  amount: number;
  reference: string | null;
  bd_bank_id: number | null;
  bank_name: string | null;
  cheque_number: string | null;
  cheque_date: string | null;
  sort_order: number;
}

export interface CustomerReceiptAllocation {
  invoice_id: number;
  invoice_no: string;
  amount: number;
}

export interface CustomerGroupReceipt {
  id: number;
  payment_date: string;
  amount: number;
  unallocated_amount: number;
  method: string | null;
  reference: string | null;
  note: string | null;
  voided_at: string | null;
  billing_profile_id: number | null;
  instruments: CustomerReceiptInstrument[];
  allocations: CustomerReceiptAllocation[];
}

export interface UpdateInstrumentDetailsPayload {
  tenant_id: number;
  instrument_id: number;
  reference?: string | null;
  bd_bank_id?: number | null;
  cheque_number?: string | null;
  cheque_date?: string | null;
}

export interface VoidCustomerReceiptPayload {
  tenant_id: number;
  payment_id: number;
  reason: string;
}

export interface VoidCustomerReceiptResult {
  success: boolean;
  payment_id: number;
  customer_group_id: number | null;
}
