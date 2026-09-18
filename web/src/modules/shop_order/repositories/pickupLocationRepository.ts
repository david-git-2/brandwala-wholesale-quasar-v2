import { supabase } from 'src/boot/supabase';

export interface PickupLocationRow {
  id: string;
  tenant_id: number;
  location_name: string;
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

export type CreatePickupLocationPayload = Omit<PickupLocationRow, 'id' | 'created_at' | 'updated_at'>;
export type UpdatePickupLocationPayload = Partial<CreatePickupLocationPayload>;

export const pickupLocationRepository = {
  async listLocations(): Promise<PickupLocationRow[]> {
    const { data, error } = await supabase
      .from('pickup_locations')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[pickupLocationRepository.listLocations error]:', error);
      throw error;
    }
    return (data as PickupLocationRow[]) || [];
  },

  async createLocation(payload: CreatePickupLocationPayload): Promise<PickupLocationRow> {
    const { data, error } = await supabase
      .from('pickup_locations')
      .insert(payload)
      .select()
      .single();

    if (error) {
      console.error('[pickupLocationRepository.createLocation error]:', error);
      throw error;
    }
    return data as PickupLocationRow;
  },

  async updateLocation(id: string, payload: UpdatePickupLocationPayload): Promise<PickupLocationRow> {
    const { data, error } = await supabase
      .from('pickup_locations')
      .update({
        ...payload,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('[pickupLocationRepository.updateLocation error]:', error);
      throw error;
    }
    return data as PickupLocationRow;
  },

  async deleteLocation(id: string): Promise<void> {
    const { error } = await supabase.from('pickup_locations').delete().eq('id', id);

    if (error) {
      console.error('[pickupLocationRepository.deleteLocation error]:', error);
      throw error;
    }
  },
};
