import { supabase } from 'src/boot/supabase';
import type { ThriftStock } from '../types';

export const thriftStockRepository = {
  async fetchStocks(tenantId: number): Promise<ThriftStock[]> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('*, thrift_pricings(*)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    
    return (data || []).map((stock: any) => ({
      ...stock,
      pricing: stock.thrift_pricings?.[0] || stock.thrift_pricings || undefined,
    })) as ThriftStock[];
  },

  async createStock(
    stock: Partial<ThriftStock>,
    pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number }
  ): Promise<ThriftStock> {
    const { data: stockData, error: stockError } = await supabase
      .from('thrift_stocks')
      .insert(stock)
      .select()
      .single();
    if (stockError) throw stockError;

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
};
