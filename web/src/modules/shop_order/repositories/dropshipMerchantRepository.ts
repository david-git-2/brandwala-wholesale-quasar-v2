import { supabase } from 'src/boot/supabase';

export interface MerchantProfileRow {
  id: string;
  tenant_id: number;
  merchant_name: string;
  store_name: string | null;
  phone_primary: string;
  phone_secondary: string | null;
  pickup_address: string;
  district: string;
  thana: string;
  notes: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export type CreateMerchantProfilePayload = Omit<MerchantProfileRow, 'id' | 'created_at' | 'updated_at'>;
export type UpdateMerchantProfilePayload = Partial<CreateMerchantProfilePayload>;

export const dropshipMerchantRepository = {
  async listMerchants(): Promise<MerchantProfileRow[]> {
    const { data, error } = await supabase
      .from('merchant_profiles')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[dropshipMerchantRepository.listMerchants error]:', error);
      throw error;
    }
    return (data as MerchantProfileRow[]) || [];
  },

  async createMerchant(payload: CreateMerchantProfilePayload): Promise<MerchantProfileRow> {
    const { data, error } = await supabase
      .from('merchant_profiles')
      .insert(payload)
      .select()
      .single();

    if (error) {
      console.error('[dropshipMerchantRepository.createMerchant error]:', error);
      throw error;
    }
    return data as MerchantProfileRow;
  },

  async updateMerchant(id: string, payload: UpdateMerchantProfilePayload): Promise<MerchantProfileRow> {
    const { data, error } = await supabase
      .from('merchant_profiles')
      .update({
        ...payload,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('[dropshipMerchantRepository.updateMerchant error]:', error);
      throw error;
    }
    return data as MerchantProfileRow;
  },

  async deleteMerchant(id: string): Promise<void> {
    const { error } = await supabase
      .from('merchant_profiles')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('[dropshipMerchantRepository.deleteMerchant error]:', error);
      throw error;
    }
  },
};
