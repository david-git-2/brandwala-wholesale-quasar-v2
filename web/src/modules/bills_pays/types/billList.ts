export type BillListSpine = 'legacy' | 'kernel';

export type BillListStatusSlug = 'draft' | 'due' | 'partial' | 'paid' | 'voided';

export type BillToProfileTypeTab =
  | 'all'
  | 'tenant'
  | 'customer'
  | 'company'
  | 'vendor'
  | 'cargo'
  | 'courier'
  | 'investor';

export type StatusPill = 'all' | BillListStatusSlug;

export type BillListRow = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  invoice_type: string;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  due_amount: number;
  currency_code?: string;
  from_profile_id?: number | null;
  from_profile_name?: string | null;
  from_profile_type?: string | null;
  to_profile_id?: number | null;
  to_profile_name?: string | null;
  to_profile_type?: string | null;
  profile_name?: string | null;
  ap_kind?: string | null;
  document_kind?: string | null;
  parent_bill_id?: number | null;
  spine?: BillListSpine;
  kind?: string | null;
  list_status?: BillListStatusSlug;
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
  toProfileType?: BillToProfileTypeTab | null;
  fromProfileId?: number | null;
  invoiceStatus?: string | null;
  paymentStatus?: string | null;
  quickFilter?: 'paid' | 'unpaid';
  pageSize?: number;
};
