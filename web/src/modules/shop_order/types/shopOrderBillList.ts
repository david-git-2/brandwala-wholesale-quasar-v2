/** Row shape from `list_bills_for_source` for `source_type = shop_order`. */
export type ShopOrderBillListItem = {
  id: number;
  invoice_no: string;
  invoice_type: string;
  document_kind: string;
  ap_kind: string | null;
  source_type: string;
  source_id: string;
  source_key: string | null;
  invoice_status: string;
  payment_status: string;
  total_amount: number;
  due_amount: number;
  parent_bill_id: number | null;
  net_balances: unknown;
};
