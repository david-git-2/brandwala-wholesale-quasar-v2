import { supabase } from 'src/boot/supabase';
import type { ThriftStock } from '../types';

interface ThriftStockDbRow {
  id: number;
  tenant_id: number;
  shipment_id: number;
  name: string;
  brand_name?: string;
  category_id: number;
  type_id: number;
  section: string;
  shelf_id: number;
  color: string;
  size: string;
  condition: string;
  barcode: string;
  stock_type: string;
  quantity: number;
  box_id?: number;
  product_weight?: number;
  extra_weight?: number;
  status: string;
  note?: string;
  inserted_by: string;
  created_at: string;
  updated_at: string;
  thrift_pricings?: Array<{
    cost_of_goods_sold: number;
    target_price: number;
    listed_price: number;
  }>;
  thrift_stock_images?: Array<{
    image_url: string;
    is_primary: boolean;
  }>;
  origin_purchase_price?: number;
}

export const thriftStockRepository = {
  async fetchStocks(tenantId: number): Promise<ThriftStock[]> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('*, thrift_pricings(*), thrift_stock_images(*)')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    
    return ((data || []) as unknown as ThriftStockDbRow[]).map((stock) => {
      const primaryImage = stock.thrift_stock_images?.find((img) => img.is_primary) || stock.thrift_stock_images?.[0];
      return {
        ...stock,
        pricing: stock.thrift_pricings?.[0] || stock.thrift_pricings || undefined,
        image_url: primaryImage?.image_url || undefined,
      };
    }) as unknown as ThriftStock[];
  },

  async createStock(
    stock: Partial<ThriftStock>,
    pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number },
    imageUrl?: string
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

    if (imageUrl) {
      const { error: imageError } = await supabase
        .from('thrift_stock_images')
        .insert({
          stock_id: stockData.id,
          image_url: imageUrl,
          is_primary: true,
          inserted_by: stockData.inserted_by,
        });
      if (imageError) console.error('Failed to link image to stock:', imageError);
    }

    return {
      ...stockData,
      pricing: pricingData,
      image_url: imageUrl,
    } as ThriftStock;
  },

  async updateStock(
    id: number,
    stock: Partial<ThriftStock>,
    pricing: { cost_of_goods_sold: number; target_price: number; listed_price: number }
  ): Promise<ThriftStock> {
    const { data: stockData, error: stockError } = await supabase
      .from('thrift_stocks')
      .update(stock)
      .eq('id', id)
      .select()
      .single();
    if (stockError) throw stockError;

    const { data: pricingData, error: pricingError } = await supabase
      .from('thrift_pricings')
      .upsert({
        stock_id: id,
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

  async deleteStock(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_stocks')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },
};
