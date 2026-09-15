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
