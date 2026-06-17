export interface ThriftCategory {
  id: number;
  tenant_id: number;
  name: string;
  description?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftType {
  id: number;
  tenant_id: number;
  name: string;
  description?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftShelf {
  id: number;
  tenant_id: number;
  name: string;
  location_bay?: string | undefined;
  shelf_code: string;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export type ThriftSection = 'MALE' | 'FEMALE' | 'UNISEX' | 'KIDS' | 'HOME';
export type ThriftCondition = 'NEW_WITH_TAGS' | 'EXCELLENT' | 'GOOD' | 'FAIR';
export type ThriftStockType = 'SINGLE' | 'BULK';
export type ThriftStockStatus = 'AVAILABLE' | 'OUT_OF_STOCK' | 'DAMAGED' | 'STOLEN';

export interface ThriftBox {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  weight?: number | undefined;
  received_weight?: number | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftStock {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  brand_name?: string | undefined;
  category_id: number;
  type_id: number;
  section: ThriftSection;
  shelf_id: number;
  color: string;
  size: string;
  condition: ThriftCondition;
  sku: string;
  stock_type: ThriftStockType;
  quantity: number;
  box_id?: number | undefined;
  product_weight?: number | undefined;
  extra_weight?: number | undefined;
  status: ThriftStockStatus;
  note?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
  pricing?: ThriftPricing;
}

export interface ThriftStockImage {
  id: number;
  stock_id: number;
  image_url: string;
  is_primary: boolean;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftPricing {
  id: number;
  stock_id: number;
  cost_of_goods_sold: number;
  target_price: number;
  listed_price: number;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export type ThriftTransactionMethod = 'CASH' | 'CARD' | 'MOBILE_BANKING' | 'COD';
export type ThriftDeliveryStatus = 'PENDING' | 'SHIPPED' | 'DELIVERED' | 'RETURNED' | 'PARTIALLY_RETURNED';
export type ThriftPaymentStatus = 'UNPAID' | 'PAID' | 'REFUNDED';

export interface ThriftInvoice {
  id: number;
  tenant_id: number;
  invoice_number: string;
  recipient_name: string;
  address: string;
  phone: string;
  transaction_method: ThriftTransactionMethod;
  delivery_status: ThriftDeliveryStatus;
  payment_status: ThriftPaymentStatus;
  cod_charge: number;
  packing_charge: number;
  invoice_print_charge: number;
  shipping_charge_customer: number;
  total_invoice_amount: number;
  inserted_by: string;
  created_at: string;
  updated_at: string;
  items?: ThriftInvoiceItem[];
}

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

export type ThriftLedgerType = 'REVENUE' | 'EXPENSE' | 'REFUND' | 'LOSS';
export type ThriftLedgerSource = 'INVOICE' | 'SHIPMENT' | 'OPERATIONAL';

export interface ThriftLedgerEntry {
  id: number;
  tenant_id: number;
  type: ThriftLedgerType;
  source: ThriftLedgerSource;
  reference_id: number;
  amount: number;
  date: string;
  inserted_by: string;
  note?: string;
  created_at: string;
  updated_at: string;
}
