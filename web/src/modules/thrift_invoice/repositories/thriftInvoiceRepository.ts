import { supabase } from 'src/boot/supabase';
import type { ThriftInvoice } from '../types';

export const thriftInvoiceRepository = {
  async fetchInvoices(tenantId: number): Promise<ThriftInvoice[]> {
    const { data, error } = await supabase
      .from('thrift_invoices')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data as ThriftInvoice[];
  },

  async markItemsAsSold(params: {
    tenantId: number;
    invoiceNumber: string;
    recipientName: string;
    address: string;
    phone: string;
    transactionMethod: string;
    codCharge: number;
    packingCharge: number;
    invoicePrintCharge: number;
    shippingChargeCustomer: number;
    insertedBy: string;
    items: Array<{
      stock_id: number;
      quantity: number;
      sold_price: number;
      platform_fees: number;
      shipping_cost_paid_by_shop: number;
    }>;
  }): Promise<number> {
    const { data, error } = await supabase.rpc('mark_thrift_items_as_sold', {
      p_tenant_id: params.tenantId,
      p_invoice_number: params.invoiceNumber,
      p_recipient_name: params.recipientName,
      p_address: params.address,
      p_phone: params.phone,
      p_transaction_method: params.transactionMethod,
      p_cod_charge: params.codCharge,
      p_packing_charge: params.packingCharge,
      p_invoice_print_charge: params.invoicePrintCharge,
      p_shipping_charge_customer: params.shippingChargeCustomer,
      p_inserted_by: params.insertedBy,
      p_items: params.items,
    });
    if (error) throw error;
    return data as number;
  },
};
