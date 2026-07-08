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

  async upsertSettings(tenantId: number, input: ThriftSettingsInput): Promise<ThriftSettings> {
    const { data, error } = await supabase
      .from('thrift_settings')
      .upsert({
        tenant_id: tenantId,
        default_origin_unit_price: input.defaultOriginUnitPrice,
        hand_tag_unit_cost: input.handTagUnitCost ?? null,
        hand_tag_unit_currency_id: input.handTagUnitCurrencyId ?? null,
        sticker_unit_cost: input.stickerUnitCost ?? null,
        sticker_unit_currency_id: input.stickerUnitCurrencyId ?? null,
      })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftSettings;
  },
};
