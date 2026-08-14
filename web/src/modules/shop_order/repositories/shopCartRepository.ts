import { supabase } from 'src/boot/supabase';

export interface CartChargesPayload {
  cod_charge_amount?: number;
  delivery_charge_amount?: number;
  print_charge_amount?: number;
  packing_charge_amount?: number;
  discount_amount?: number;
  is_prepaid?: boolean;
  delivery_instructions?: string | null;
}

export interface CartData {
  cart: {
    id: number;
    tenant_id: number;
    shop_id: number;
    customer_group_id: number;
    see_price_snapshot: boolean;
    status: 'active' | 'converted' | 'abandoned';
    shop_type: 'vendor_catalog' | 'fixed_price' | 'dropship';
    allow_delivery: boolean;
    created_at: string;
    updated_at: string;
    cod_charge_amount?: number;
    delivery_charge_amount?: number;
    print_charge_amount?: number;
    packing_charge_amount?: number;
    default_print_charge_amount?: number;
    default_packing_charge_amount?: number;
    discount_amount?: number;
    is_prepaid?: boolean;
    delivery_instructions?: string | null;
    deduct_charges_from_margin?: boolean;
    deduct_print_from_margin?: boolean;
    deduct_packing_from_margin?: boolean;
  };
  items: Array<{
    id: number;
    cart_id: number;
    product_id: number;
    global_stock_id: number | null;
    global_stock_allocation_id: number | null;
    quantity: number;
    minimum_quantity: number;
    unit_list_price_amount: number | null;
    unit_list_price_currency_id: number | null;
    unit_sell_price_amount: number | null;
    unit_sell_price_currency_id: number | null;
    unit_minimum_sell_price_amount: number | null;
    unit_minimum_sell_price_currency_id: number | null;
    customer_sell_price_amount: number | null;
    customer_sell_price_currency_id: number | null;
    name: string;
    image_url: string | null;
  }>;
}

const getOrCreateCart = async (shopId: number): Promise<CartData> => {
  const { data, error } = await supabase.rpc('get_or_create_shop_cart', {
    p_shop_id: shopId,
  });

  if (error) {
    throw error;
  }

  return data as CartData;
};

const addToCart = async (
  shopId: number,
  productId: number,
  globalStockAllocationId: number | null,
  quantity: number,
  customerSellPriceAmount?: number | null,
  customerSellPriceCurrencyId?: number | null,
  globalStockId?: number | null,
): Promise<CartData> => {
  const { data, error } = await supabase.rpc('add_to_shop_cart', {
    p_shop_id: shopId,
    p_product_id: productId,
    p_global_stock_allocation_id: globalStockAllocationId ?? globalStockId ?? null,
    p_quantity: quantity,
    p_customer_sell_price_amount: customerSellPriceAmount ?? null,
    p_customer_sell_price_currency_id: customerSellPriceCurrencyId ?? null,
    p_global_stock_id: globalStockId ?? globalStockAllocationId ?? null,
  });

  if (error) {
    throw error;
  }

  return data as CartData;
};

const updateCartItemQty = async (cartItemId: number, quantity: number): Promise<CartData> => {
  const { data, error } = await supabase.rpc('update_shop_cart_item_qty', {
    p_cart_item_id: cartItemId,
    p_quantity: quantity,
  });

  if (error) {
    throw error;
  }

  return data as CartData;
};

const removeCartItem = async (cartItemId: number): Promise<CartData> => {
  const { data, error } = await supabase.rpc('remove_shop_cart_item', {
    p_cart_item_id: cartItemId,
  });

  if (error) {
    throw error;
  }

  return data as CartData;
};

const updateCartItemPrice = async (cartItemId: number, price: number): Promise<CartData> => {
  const { data, error } = await supabase.rpc('update_shop_cart_item_price', {
    p_cart_item_id: cartItemId,
    p_price: price,
  });

  if (error) {
    throw error;
  }

  return data as CartData;
};

const updateShopCartCharges = async (
  shopId: number,
  cartId: number,
  charges: CartChargesPayload,
): Promise<CartData> => {
  const { error } = await supabase
    .from('shop_carts')
    .update(charges)
    .eq('id', cartId);

  if (error) {
    throw error;
  }

  return getOrCreateCart(shopId);
};

export interface ActiveCartItem {
  cart_id: number;
  shop_id: number;
  shop_name: string;
  shop_slug: string;
  shop_logo_url: string | null;
  shop_type: 'vendor_catalog' | 'fixed_price' | 'dropship';
  see_price: boolean;
  currency_id: number | null;
  currency_code: string | null;
  currency_symbol: string | null;
  item_count: number;
  cart_total: number | null;
  updated_at: string;
}

const listActiveShopCarts = async (): Promise<ActiveCartItem[]> => {
  const { data, error } = await supabase.rpc('list_active_shop_carts');

  if (error) {
    throw error;
  }

  return (data ?? []).map((row: Record<string, any>) => ({
    cart_id: Number(row.cart_id),
    shop_id: Number(row.shop_id),
    shop_name: row.shop_name,
    shop_slug: row.shop_slug,
    shop_logo_url: row.shop_logo_url ?? null,
    shop_type: row.shop_type as ActiveCartItem['shop_type'],
    see_price: row.see_price,
    currency_id: row.currency_id ?? null,
    currency_code: row.currency_code ?? null,
    currency_symbol: row.currency_symbol ?? null,
    item_count: Number(row.item_count ?? 0),
    cart_total: row.cart_total == null ? null : Number(row.cart_total),
    updated_at: row.updated_at,
  }));
};

export const shopCartRepository = {
  getOrCreateCart,
  listActiveShopCarts,
  addToCart,
  updateCartItemQty,
  removeCartItem,
  updateCartItemPrice,
  updateShopCartCharges,
};

