import { supabase } from 'src/boot/supabase';
import type { ThriftSettings, ThriftSettingsInput } from '../types';

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
    input: ThriftSettingsInput,
  ): Promise<ThriftSettings> {
    const { data, error } = await supabase
      .from('thrift_settings')
      .upsert({
        tenant_id: tenantId,
        default_origin_purchase_price: input.defaultOriginPurchasePrice,
      })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftSettings;
  },
};
