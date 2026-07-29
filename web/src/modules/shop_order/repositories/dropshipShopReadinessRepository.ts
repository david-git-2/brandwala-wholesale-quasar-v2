import { supabase } from 'src/boot/supabase';

export interface DropshipShopReadiness {
  shop_id: number;
  has_access_group_with_price: boolean;
  has_customer_group_with_members: boolean;
  has_billing_profile_linked: boolean;
  has_listing_with_floor: boolean;
  has_active_courier: boolean;
  ready: boolean;
}

export const dropshipShopReadinessRepository = {
  async getDropshipShopReadiness(shopId: number): Promise<DropshipShopReadiness | null> {
    const { data, error } = await supabase.rpc('get_dropship_shop_readiness', {
      p_shop_id: shopId,
    });

    if (error) {
      throw error;
    }

    const rows = data as DropshipShopReadiness[] | null;
    return rows?.[0] ?? null;
  },
};
