/** Shape from kernel `get_bill_net_balances` / bundle `net_balances`. */
export type BillNetBalances = {
  bill_id: number;
  invoice_no: string;
  original_total: number;
  paid_amount: number;
  credits_issued: number;
  debits_issued: number;
  due_amount: number;
  credit_open: number;
  document_kind: string;
  open_books?: number;
  open_txn?: number;
};
