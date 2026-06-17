import { supabase } from 'src/boot/supabase';
import type {
  ThriftCategory,
  ThriftType,
  ThriftShelf,
  ThriftStock,
  ThriftInvoice,
  ThriftLedgerEntry,
  ThriftBox,
} from '../types';

export const thriftRepository = {
  // --- Categories ---
  async fetchCategories(tenantId: number): Promise<ThriftCategory[]> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftCategory[];
  },

  async createCategory(category: Partial<ThriftCategory>): Promise<ThriftCategory> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .insert(category)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftCategory;
  },

  // --- Types ---
  async fetchTypes(tenantId: number): Promise<ThriftType[]> {
    const { data, error } = await supabase
      .from('thrift_types')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftType[];
  },

  async createType(type: Partial<ThriftType>): Promise<ThriftType> {
    const { data, error } = await supabase
      .from('thrift_types')
      .insert(type)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftType;
  },

  // --- Shelves ---
  async fetchShelves(tenantId: number): Promise<ThriftShelf[]> {
    const { data, error } = await supabase
      .from('thrift_shelves')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('shelf_code', { ascending: true });
    if (error) throw error;
    return data as ThriftShelf[];
  },

  async createShelf(shelf: Partial<ThriftShelf>): Promise<ThriftShelf> {
    const { data, error } = await supabase
      .from('thrift_shelves')
      .insert(shelf)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftShelf;
  },

  // --- Boxes ---
  async fetchBoxes(tenantId: number): Promise<ThriftBox[]> {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftBox[];
  },

  async createBox(box: Partial<ThriftBox>): Promise<ThriftBox> {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .insert(box)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftBox;
  },

  async deleteBox(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_boxes')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },

  // --- Stocks ---
  async fetchStocks(tenantId: number): Promise<ThriftStock[]> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('*, thrift_pricings(*)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    
    return (data || []).map((stock: Record<string, unknown>) => ({
      ...stock,
      pricing: (stock.thrift_pricings as unknown[])?.[0] || stock.thrift_pricings || undefined,
    })) as ThriftStock[];
  },

  async createStock(
    stock: Partial<ThriftStock>,
    pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number }
  ): Promise<ThriftStock> {
    // 1. Insert stock
    const { data: stockData, error: stockError } = await supabase
      .from('thrift_stocks')
      .insert(stock)
      .select()
      .single();
    if (stockError) throw stockError;

    // 2. Insert pricing
    const { data: pricingData, error: pricingError } = await supabase
      .from('thrift_pricings')
      .insert({
        stock_id: stockData.id,
        cost_of_goods_sold: pricing.cost_of_goods_sold,
        target_price: pricing.target_price,
        listed_price: pricing.listed_price,
        inserted_by: stockData.inserted_by,
      })
      .select()
      .single();
    if (pricingError) throw pricingError;

    return {
      ...stockData,
      pricing: pricingData,
    } as ThriftStock;
  },

  async updateStockStatus(id: number, status: string): Promise<void> {
    const { error } = await supabase
      .from('thrift_stocks')
      .update({ status })
      .eq('id', id);
    if (error) throw error;
  },

  // --- Invoices ---
  async fetchInvoices(tenantId: number): Promise<ThriftInvoice[]> {
    const { data, error } = await supabase
      .from('thrift_invoices')
      .select('*, thrift_invoice_items(*)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data as ThriftInvoice[];
  },

  // --- RPC Mark as Sold ---
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

  // --- Ledger ---
  async fetchLedger(tenantId: number): Promise<ThriftLedgerEntry[]> {
    const { data, error } = await supabase
      .from('thrift_accounting_ledger')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('date', { ascending: false });
    if (error) throw error;
    return data as ThriftLedgerEntry[];
  },
};
