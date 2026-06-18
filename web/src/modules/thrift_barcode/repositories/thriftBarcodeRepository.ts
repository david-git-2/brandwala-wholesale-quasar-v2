import { supabase } from 'src/boot/supabase';
import type { ThriftBarcode } from '../types';

export const thriftBarcodeRepository = {
  async fetchBarcodes(tenantId: number): Promise<ThriftBarcode[]> {
    const { data, error } = await supabase
      .from('thrift_barcodes')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    return data as ThriftBarcode[];
  },

  async generateBarcodes(params: {
    tenantId: number;
    quantity: number;
    insertedBy: string;
  }): Promise<string[]> {
    const { data, error } = await supabase.rpc('generate_thrift_barcodes', {
      p_tenant_id: params.tenantId,
      p_quantity: params.quantity,
      p_inserted_by: params.insertedBy,
    });

    if (error) throw error;
    return data as string[];
  },

  async markBarcodesPrinted(ids: number[]): Promise<void> {
    if (!ids.length) return;
    const { error } = await supabase
      .from('thrift_barcodes')
      .update({ is_printed: 1 })
      .in('id', ids);

    if (error) throw error;
  },
};
