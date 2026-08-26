import { supabase } from 'src/boot/supabase';
import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type { ShopCatalogPrice } from '../types';

export interface DropshipCartLineTotals {
  purchase_subtotal: number;
  resell_subtotal: number;
}

export interface DropshipCartItem {
  id: number;
  product_id: number;
  global_stock_id: number | null;
  name: string;
  image_url: string | null;
  quantity: number;
  minimum_quantity: number;
  minimum_order_quantity: number | null;
  purchase_price: ShopCatalogPrice;
  listing_sell_price: ShopCatalogPrice;
  resell_price: ShopCatalogPrice;
  min_resell_price: ShopCatalogPrice;
  line_totals: DropshipCartLineTotals;
  is_resell_below_floor: boolean;
}

export interface DropshipCartTotals {
  item_count: number;
  line_count: number;
  purchase_subtotal: number;
  resell_subtotal: number;
  estimated_profit: number;
}

export interface DropshipCartData {
  cart: {
    id: number;
    tenant_id: number;
    shop_id: number;
    shop_name: string;
    shop_slug: string;
    customer_group_id: number;
    status: 'active' | 'converted' | 'abandoned';
    allow_delivery: boolean;
    currency: {
      id: number | null;
      code: string | null;
      symbol: string | null;
    };
    charges: {
      cod_charge_amount: number;
      delivery_charge_amount: number;
      print_charge_amount: number;
      packing_charge_amount: number;
      discount_amount: number;
      is_prepaid: boolean;
      delivery_instructions: string | null;
    };
    margin_deductions: {
      deduct_charges_from_margin: boolean;
      deduct_print_from_margin: boolean;
      deduct_packing_from_margin: boolean;
    };
    created_at: string;
    updated_at: string;
  };
  permissions: CustomerShopPermissions | null;
  items: DropshipCartItem[];
  totals: DropshipCartTotals;
}

export interface DropshipChargeEstimates {
  delivery_min: number;
  delivery_max: number;
  delivery_mid: number;
  cod_percent_min: number;
  cod_percent_max: number;
  cod_charge_preview: number;
}

export interface DropshipReviewSummary {
  total_units: number;
  has_floor_violation: boolean;
  recipient_grand_total: number;
  can_continue: boolean;
}

export interface DropshipReviewCartData extends DropshipCartData {
  charge_estimates: DropshipChargeEstimates;
  review_summary: DropshipReviewSummary;
}

const getDropshipShopCart = async (shopId: number): Promise<DropshipCartData> => {
  const { data, error } = await supabase.rpc('get_dropship_shop_cart', {
    p_shop_id: shopId,
  });

  if (error) {
    throw error;
  }

  return data as DropshipCartData;
};

const getDropshipReviewCart = async (shopId: number): Promise<DropshipReviewCartData> => {
  const { data, error } = await supabase.rpc('get_dropship_review_cart', {
    p_shop_id: shopId,
  });

  if (error) {
    throw error;
  }

  return data as DropshipReviewCartData;
};

export const dropshipCartRepository = {
  getDropshipShopCart,
  getDropshipReviewCart,
};
