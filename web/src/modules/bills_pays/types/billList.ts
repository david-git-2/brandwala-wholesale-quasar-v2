export type BillListRow = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  invoice_type: string;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  due_amount: number;
  recipient_name?: string | null;
  profile_name?: string | null;
  retail_billing_mode?: 'account' | 'direct' | null;
  channel_meta?: Record<string, unknown> | null;
  ap_kind?: string | null;
};

export type BillsListPageCursor = number | null;

export type BillsListPageMeta = {
  has_more: boolean;
  next_cursor: BillsListPageCursor;
};

export type BillsListPageResult = {
  data: BillListRow[];
  meta: BillsListPageMeta;
};

export type ListBillsDeskPageParams = {
  parentTenantId: number | null;
  issuedByTenantId?: number | null;
  arSide?: 'they_owe' | 'we_owe';
  invoiceStatus?: string | null;
  paymentStatus?: string | null;
  quickFilter?: 'paid' | 'unpaid';
  search?: string;
  pageSize?: number;
};
