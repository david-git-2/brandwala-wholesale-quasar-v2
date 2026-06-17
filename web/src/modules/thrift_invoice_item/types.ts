export type ThriftItemStatus = 'SOLD' | 'RETURNED';
export type ThriftReturnAction = 'RESTOCK' | 'WRITE_OFF';

export interface ThriftInvoiceItem {
  id: number;
  invoice_id: number;
  stock_id: number;
  quantity: number;
  sold_price: number;
  platform_fees: number;
  shipping_cost_paid_by_shop: number;
  item_status: ThriftItemStatus;
  return_reason?: string;
  return_cost_charged_to_customer: number;
  return_cost_paid_by_shop: number;
  return_action?: ThriftReturnAction;
  net_profit: number;
  created_at: string;
  updated_at: string;
}
