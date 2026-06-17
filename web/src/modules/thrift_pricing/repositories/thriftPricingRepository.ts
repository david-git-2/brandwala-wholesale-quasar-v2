import { supabase } from 'src/boot/supabase';
import type { ThriftPricing } from '../types';

export const thriftPricingRepository = {
  async fetchPricings(tenantId: number): Promise<ThriftPricing[]> {
    // We join thrift_pricings with thrift_stocks to filter by tenant_id
    const { data, error } = await supabase
      .from('thrift_pricings')
      .select('*, thrift_stocks!inner(tenant_id, name, sku)')
      .eq('thrift_stocks.tenant_id', tenantId);
    if (error) throw error;
    return data as any[];
  },

  async updatePricing(id: number, cost: number, target: number, listed: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_pricings')
      .update({
        cost_of_goods_sold: cost,
        target_price: target,
        listed_price: listed,
      })
      .eq('id', id);
    if (error) throw error;
  },
};
