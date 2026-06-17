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
}
