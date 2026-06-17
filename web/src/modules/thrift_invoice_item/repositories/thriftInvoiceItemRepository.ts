import { supabase } from 'src/boot/supabase';
import type { ThriftInvoiceItem } from '../types';

export const thriftInvoiceItemRepository = {
  async fetchInvoiceItems(tenantId: number): Promise<ThriftInvoiceItem[]> {
    // We join thrift_invoice_items -> thrift_invoices to scope by tenant_id
    const { data, error } = await supabase
      .from('thrift_invoice_items')
      .select('*, thrift_invoices!inner(tenant_id, invoice_number), thrift_stocks!inner(name, sku)')
      .eq('thrift_invoices.tenant_id', tenantId);
    if (error) throw error;
    return data as any[];
  },
};
