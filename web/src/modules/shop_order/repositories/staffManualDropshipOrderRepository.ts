import { supabase } from 'src/boot/supabase';

export interface StaffDropshipListingRow {
  listing_id: number;
  product_id: number;
  grade_tag_id: number;
  global_stock_id: number | null;
  product_name: string;
  product_image_url: string | null;
  product_barcode: string | null;
  sell_price_amount: number;
  sell_price_currency_id: number;
  minimum_sell_price_amount: number | null;
  minimum_sell_price_currency_id: number | null;
  available_to_sell: number;
}

export interface StaffDropshipOrderLineInput {
  product_id: number;
  listing_id: number;
  grade_tag_id?: number;
  global_stock_id?: number | null;
  quantity: number;
  customer_sell_price_amount?: number;
  customer_sell_price_currency_id?: number;
}

export interface StaffDropshipSubmitResult {
  order_id: number;
  order_no: string;
  status: string;
  billing_profile_warning?: boolean;
}

const browseListings = async (
  tenantId: number,
  shopId: number,
  customerGroupId: number,
  search: string,
  limit = 24,
): Promise<StaffDropshipListingRow[]> => {
  const { data, error } = await supabase.rpc('browse_dropship_listings_for_staff_order', {
    p_tenant_id: tenantId,
    p_shop_id: shopId,
    p_customer_group_id: customerGroupId,
    p_search: search || null,
    p_limit: limit,
  });
  if (error) throw error;
  const payload = (data ?? {}) as { data?: StaffDropshipListingRow[] };
  return payload.data ?? [];
};

const createOrder = async (
  shopId: number,
  customerGroupId: number,
  items: StaffDropshipOrderLineInput[],
  payload: {
    recipientName: string;
    recipientPhone: string;
    shippingAddress: string;
    recipientPhoneSecondary?: string | null;
    shippingDistrict?: string | null;
    shippingThana?: string | null;
    deliveryInstructions?: string | null;
  },
): Promise<StaffDropshipSubmitResult> => {
  const { data, error } = await supabase.rpc('staff_create_dropship_order', {
    p_shop_id: shopId,
    p_customer_group_id: customerGroupId,
    p_items: items,
    p_recipient_name: payload.recipientName,
    p_recipient_phone: payload.recipientPhone,
    p_shipping_address: payload.shippingAddress,
    p_recipient_phone_secondary: payload.recipientPhoneSecondary ?? null,
    p_shipping_district: payload.shippingDistrict ?? null,
    p_shipping_thana: payload.shippingThana ?? null,
    p_profile_id: null,
    p_delivery_instructions: payload.deliveryInstructions ?? null,
  });
  if (error) throw error;
  return data as StaffDropshipSubmitResult;
};

export const staffManualDropshipOrderRepository = {
  browseListings,
  createOrder,
};
