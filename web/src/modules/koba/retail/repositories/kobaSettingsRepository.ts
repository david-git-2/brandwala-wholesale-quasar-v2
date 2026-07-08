import { supabase } from 'src/boot/supabase';
import type { PostgrestError } from '@supabase/supabase-js';

export interface KobaRetailSettings {
  id: number;
  tenant_id: number;
  cod_charge_pct: number;
  gateway_charge_flat: number;
  packing_charge_flat: number;
  invoice_charge_flat: number;
  extra_profit_user_pct: number;
  extra_profit_company_pct: number;
  delivery_rates: Record<string, number>;
  updated_at: string;
}

export const kobaSettingsRepository = {
  async getSettings(
    tenantId: number,
  ): Promise<{ data: KobaRetailSettings | null; error: PostgrestError | null }> {
    const { data, error } = await supabase
      .from('koba_retail_settings')
      .select('*')
      .eq('tenant_id', tenantId)
      .maybeSingle();

    return { data, error };
  },

  async updateSettings(
    settings: Partial<KobaRetailSettings>,
  ): Promise<{ data: KobaRetailSettings | null; error: PostgrestError | null }> {
    if (settings.id && settings.id > 0) {
      const { data, error } = await supabase
        .from('koba_retail_settings')
        .update(settings)
        .eq('id', settings.id)
        .select('*')
        .single();

      return { data, error };
    } else {
      const insertData = { ...settings };
      delete insertData.id;
      const { data, error } = await supabase
        .from('koba_retail_settings')
        .insert(insertData)
        .select('*')
        .single();

      return { data, error };
    }
  },
};
