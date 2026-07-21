import { supabase } from 'src/boot/supabase';

export interface CourierServiceRow {
  id: string;
  tenant_id: number | null;
  code: string;
  name: string;
  is_active: boolean;
  cod_fee_mode: 'none' | 'percent_of_collect' | 'flat' | 'tiered_manual';
  cod_fee_percent: number;
  cod_fee_flat_amount: number;
  cod_fee_notes: string | null;
  deduct_cod_from_margin_default: boolean;
  inside_dhaka_fee: number;
  outside_dhaka_fee: number;
  inside_dhaka_return_fee: number;
  outside_dhaka_return_fee: number;
  return_fee_mode: 'none' | 'percent_of_forward' | 'flat' | 'tiered_manual';
  return_fee_percent: number;
  delivery_attempt_count: number;
  hub_hold_days: number;
  open_box_default_allowed: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export type CreateCourierServicePayload = Omit<CourierServiceRow, 'id' | 'created_at' | 'updated_at'>;
export type UpdateCourierServicePayload = Partial<CreateCourierServicePayload>;

export const dropshipCourierRepository = {
  async listCouriers(): Promise<CourierServiceRow[]> {
    const { data, error } = await supabase
      .from('courier_services')
      .select('*')
      .order('created_at', { ascending: true });

    if (error) {
      console.error('[dropshipCourierRepository.listCouriers error]:', error);
      throw error;
    }
    return (data as CourierServiceRow[]) || [];
  },

  async createCourier(payload: CreateCourierServicePayload): Promise<CourierServiceRow> {
    const { data, error } = await supabase
      .from('courier_services')
      .insert(payload)
      .select()
      .single();

    if (error) throw error;
    return data as CourierServiceRow;
  },

  async updateCourier(id: string, payload: UpdateCourierServicePayload): Promise<CourierServiceRow> {
    const { data, error } = await supabase
      .from('courier_services')
      .update({
        ...payload,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return data as CourierServiceRow;
  },

  async deleteCourier(id: string): Promise<void> {
    const { error } = await supabase
      .from('courier_services')
      .delete()
      .eq('id', id);

    if (error) throw error;
  },
};
