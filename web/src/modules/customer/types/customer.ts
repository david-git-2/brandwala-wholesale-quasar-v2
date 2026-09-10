export interface CustomerListMeta {
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface CustomerListPageResult {
  data: CustomerAccount[];
  meta: CustomerListMeta;
}

export interface CustomerAccount {
  id: number;
  customer_group_id: number;
  billing_profile_id: number | null;
  group_name: string;
  admin_name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  accent_color: string;
  is_active: boolean;
  member_count: number;
  wallet_available_balance: number;
  created_at: string;
}

export interface CreateCustomerInput {
  tenant_id: number;
  group_name: string;
  phone: string;
  phone_country_code: string;
}

export interface CustomerGroupMember {
  id: number;
  customer_group_id: number;
  name: string;
  email: string;
  role: 'admin' | 'manager' | 'staff';
  is_active: boolean;
  tenant_role_id?: number | null;
  created_at?: string;
  updated_at?: string;
}

export interface CustomerGroupMemberCreateInput {
  customer_group_id: number;
  name: string;
  email: string;
  role: 'admin' | 'manager' | 'staff';
  is_active: boolean;
  tenant_role_id?: number | null;
}

export interface CustomerGroupMemberUpdateInput {
  id: number;
  customer_group_id?: number;
  name?: string;
  email?: string;
  role?: 'admin' | 'manager' | 'staff';
  is_active?: boolean;
  tenant_role_id?: number | null;
}

export interface UpdateCustomerInput {
  id: number;
  tenant_id: number;
  customer_group_id: number;
  billing_profile_id?: number | null;
  group_name: string;
  admin_name: string;
  email?: string | null;
  phone?: string | null;
  phone_country_code?: string | null;
  address?: string | null;
  accent_color?: string | null;
  is_active?: boolean;
}

export interface CustomerAccountOpenInvoice {
  id: number;
  invoice_no: string;
  invoice_type: string;
  due_amount: number;
  paid_amount: number;
  total_amount: number;
  payment_status: string;
  invoice_date: string;
  due_date: string | null;
  issued_by_tenant_id: number;
  issued_by_tenant_name: string | null;
}

export interface CustomerAccountRecentPayment {
  payment_id: number;
  payment_date: string;
  method: string;
  amount: number;
  unallocated_amount: number;
  note: string | null;
  invoice_id: number | null;
  allocated_amount: number | null;
}

export interface CustomerAccountLedgerRow {
  id: string;
  type: string;
  amount: number;
  balance_after: number;
  operating_tenant_id: number | null;
  source_type: string;
  source_id: string | null;
  created_at: string;
  transaction_type: string | null;
  label: string;
}

export interface CustomerAccountShopAccess {
  shop_id: number;
  shop_name: string;
  shop_type: string;
  shop_tenant_id: number;
  shop_tenant_name: string;
  status: boolean;
  credit_limit_amount: number | null;
}

export interface CustomerAccountSummary {
  success: boolean;
  error?: string;
  books_tenant_id?: number;
  billing_profile_id: number | null;
  still_due: number;
  total_billed: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  store_credit_balance: number;
  unallocated_payments: number;
  open_invoices: CustomerAccountOpenInvoice[];
  recent_payments: CustomerAccountRecentPayment[];
  recent_ledger: CustomerAccountLedgerRow[];
  shop_access: CustomerAccountShopAccess[];
}
