import { supabase } from 'src/boot/supabase';
import type { ThriftSettings } from '../types';

export const thriftSettingsRepository = {
  async fetchSettings(tenantId: number): Promise<ThriftSettings | null> {
    const { data, error } = await supabase
      .from('thrift_settings')
      .select('*')
      .eq('tenant_id', tenantId)
      .maybeSingle();
    if (error) throw error;
    return data as ThriftSettings | null;
  },

  async upsertSettings(
    tenantId: number,
    defaultPurchasePriceGbp: number,
  ): Promise<ThriftSettings> {
    const { data, error } = await supabase
      .from('thrift_settings')
      .upsert({
        tenant_id: tenantId,
        default_purchase_price_gbp: defaultPurchasePriceGbp,
      })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftSettings;
  },
};
