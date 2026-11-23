export type CustomerReportSectionKind = 'payments' | 'orders' | 'bills' | 'ledger';

export type CustomersReportListRow = {
  customer_group_id: number;
  profile_id: number | null;
  name: string;
  phone: string | null;
  is_active: boolean;
  member_count: number;
  still_due: number;
  store_credit_balance: number;
  created_at: string;
};

export type CustomerReportListPayload = {
  success: boolean;
  error?: string;
  items: CustomersReportListRow[];
  next_cursor: string | null;
};

export type CustomerReportMember = {
  id: number;
  name: string;
  email: string;
  role: string;
  is_active: boolean;
  created_at: string;
};

export type CustomerReportShopAccess = {
  shop_id: number;
  shop_name: string;
  shop_type: string;
  shop_tenant_id: number;
  shop_tenant_name: string;
  status: boolean;
  credit_limit_amount: number | null;
};

export type CustomerReportHeader = {
  success: boolean;
  error?: string;
  customer_group_id: number;
  group_name: string;
  profile_id: number | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  is_active: boolean;
  accent_color: string | null;
  created_at: string;
  still_due: number;
  total_billed: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  store_credit_balance: number;
  unallocated_payments: number;
  members: CustomerReportMember[];
  shop_access: CustomerReportShopAccess[];
};

export type CustomerReportPaymentRow = {
  payment_id: number;
  payment_date: string;
  method: string | null;
  amount: number;
  unallocated_amount: number;
  purpose_code: string | null;
  source: string | null;
  voided_at: string | null;
  note: string | null;
};

export type CustomerReportOrderRow = {
  order_id: number;
  order_no: string;
  name: string | null;
  status: string;
  shop_id: number | null;
  shop_name: string | null;
  cod_collect_amount: number | null;
  payout_settlement_status: string | null;
  recipient_name: string | null;
  recipient_phone: string | null;
  created_at: string;
};

export type CustomerReportBillRow = {
  bill_id: number;
  invoice_no: string;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  paid_amount: number;
  due_amount: number;
  written_off_amount: number;
  shop_order_id: number | null;
  invoice_date: string;
};

export type CustomerReportLedgerRow = {
  entry_id: string;
  type: string;
  amount: number;
  balance_after: number;
  currency_code: string;
  source_type: string;
  source_id: string | null;
  created_at: string;
  label: string;
  payment_id: string | null;
};

export type CustomerReportSectionPayload = {
  success: boolean;
  error?: string;
  kind: CustomerReportSectionKind;
  items: unknown[];
  next_cursor: string | null;
};