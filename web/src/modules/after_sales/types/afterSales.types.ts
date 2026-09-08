export type AfterSalesSourceChannel = 'wholesale' | 'dropship';

export type AfterSalesProgram = 'return_credit' | 'doa' | 'replacement' | 'warranty';

export type AfterSalesCaseStatus =
  | 'draft'
  | 'pending_approval'
  | 'approved'
  | 'awaiting_receipt'
  | 'received'
  | 'inspecting'
  | 'executing'
  | 'closed'
  | 'rejected';

export type DropshipIntakeSource = 'phone' | 'whatsapp' | 'in_person' | 'email' | 'other';

export type DropshipReportedTo = 'company' | 'merchant';

export type AfterSalesReasonCode = 'unused' | 'wrong_item' | 'doa' | 'warranty' | 'other';

export type AfterSalesOutcome = 'pending' | 'credit' | 'replace' | 'repair' | 'reject';

export type AfterSalesWindowAnchor = 'invoice_date' | 'delivery_date';

export type AfterSalesRestockFeeType = 'none' | 'percent' | 'flat_bdt';

export type AfterSalesPolicySnapshot = {
  policy_id: string;
  policy_name: string;
  program: AfterSalesProgram;
  window_days: number;
  window_anchor: AfterSalesWindowAnchor;
  within_window: boolean;
  restock_fee_type: AfterSalesRestockFeeType;
  restock_fee_value: number;
  suggested_restock_fee: number;
  requires_approval: boolean;
  approval_threshold_bdt: number;
};

export type AfterSalesPolicyProgram = {
  id: string;
  parent_tenant_id: number;
  name: string;
  program: AfterSalesProgram;
  is_active: boolean;
  window_days: number;
  window_anchor: AfterSalesWindowAnchor;
  allowed_outcomes: AfterSalesOutcome[];
  restock_fee_type: AfterSalesRestockFeeType;
  restock_fee_value: number;
  default_to_availability: 'held' | 'sellable' | 'unsellable';
  requires_approval: boolean;
  approval_threshold_bdt: number;
  customer_visible_note: string | null;
};

export type AfterSalesPolicyListFilters = {
  program?: AfterSalesProgram | null;
  search?: string | null;
  active_only?: boolean;
};

export type AfterSalesCaseLine = {
  id: string;
  invoice_item_id: number | null;
  shop_order_item_id: number | null;
  product_name: string;
  requested_qty: number;
  received_qty: number;
  outcome: AfterSalesOutcome;
  restock_fee_amount: number;
  grade_label: string | null;
};

export type AfterSalesCaseEvent = {
  id: string;
  event_type: string;
  label: string;
  occurred_at: string;
  actor_name: string | null;
};

export type AfterSalesCase = {
  id: string;
  case_no: string;
  status: AfterSalesCaseStatus;
  source_channel: AfterSalesSourceChannel;
  reason_code: AfterSalesReasonCode;
  program: AfterSalesProgram;
  parent_tenant_id: number;
  operating_tenant_id: number;
  operating_tenant_name: string;
  sales_invoice_id: number | null;
  sales_invoice_no: string | null;
  shop_order_id: number | null;
  shop_order_no: string | null;
  billing_profile_id: number | null;
  customer_name: string;
  policy_snapshot: AfterSalesPolicySnapshot;
  intake_source: DropshipIntakeSource | null;
  reported_to: DropshipReportedTo | null;
  reporter_name: string | null;
  reporter_phone: string | null;
  intake_note: string | null;
  opened_at: string;
  closed_at: string | null;
  lines: AfterSalesCaseLine[];
  events: AfterSalesCaseEvent[];
};

export type AfterSalesHubSummary = {
  open_cases: number;
  pending_approval: number;
  awaiting_receipt: number;
  wholesale_count: number;
  dropship_count: number;
  closed_this_month: number;
};

export type AfterSalesCaseListFilters = {
  channel?: AfterSalesSourceChannel | null;
  status?: AfterSalesCaseStatus | null;
  reason?: AfterSalesReasonCode | null;
  search?: string | null;
  operating_tenant_id?: number | null;
  date_from?: string | null;
  date_to?: string | null;
};

export type MockChildTenant = {
  id: number;
  name: string;
};

export type MockDropshipOrder = {
  id: number;
  order_no: string;
  recipient_name: string;
  recipient_phone: string;
  merchant_name: string;
  merchant_billing_profile_id: number;
};

export type CreateWholesaleCasePayload = {
  parent_tenant_id: number;
  operating_tenant_id: number;
  operating_tenant_name: string;
  sales_invoice_id: number;
  sales_invoice_no: string;
  billing_profile_id: number | null;
  customer_name: string;
  reason_code: AfterSalesReasonCode;
  lines: Array<{
    invoice_item_id: number;
    product_name: string;
    requested_qty: number;
  }>;
};

export type CreateDropshipCasePayload = {
  parent_tenant_id: number;
  operating_tenant_id: number;
  operating_tenant_name: string;
  shop_order_id: number;
  shop_order_no: string;
  merchant_billing_profile_id: number;
  customer_name: string;
  intake_source: DropshipIntakeSource;
  reported_to: DropshipReportedTo;
  reporter_name: string;
  reporter_phone: string;
  reason_code: AfterSalesReasonCode;
  intake_note: string;
};

export type PolicyPreviewResult = AfterSalesPolicySnapshot;
