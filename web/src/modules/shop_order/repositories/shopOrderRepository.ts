import { supabase } from 'src/boot/supabase';
import type {
  Shop,
  CreateShopPayload,
  UpdateShopPayload,
  ShopOrder,
  ShopOrderItem,
} from '../types';

const listShops = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; search?: string | null; active?: boolean | null } = {},
): Promise<Shop[]> => {
  const { data, error } = await supabase.rpc('list_shops', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 200,
    p_offset: opts.offset ?? 0,
    p_search: opts.search ?? null,
    p_active: opts.active ?? null,
  });

  if (error) {
    throw error;
  }

  return (data as Shop[] | null) ?? [];
};

const upsertShop = async (payload: CreateShopPayload | UpdateShopPayload): Promise<Shop> => {
  const isEdit = 'id' in payload && typeof (payload as UpdateShopPayload).id === 'number';

  const { data, error } = await supabase.rpc('upsert_shop', {
    p_tenant_id: payload.tenant_id,
    p_name: payload.name.trim(),
    p_slug: payload.slug.trim().toLowerCase(),
    p_order_mode: payload.order_mode,
    p_is_negotiable: payload.is_negotiable,
    p_show_stock_quantity: payload.show_stock_quantity,
    p_is_active: payload.is_active,
    // create-only
    p_shop_type: isEdit ? null : (payload as CreateShopPayload).shop_type,
    p_vendor_code: isEdit ? null : (payload as CreateShopPayload).vendor_code?.trim() || null,
    // optional
    p_id: isEdit ? (payload as UpdateShopPayload).id : null,
    p_default_currency_id: payload.default_currency_id ?? null,
    p_global_stock_type_id: payload.global_stock_type_id ?? null,
    p_allow_delivery: payload.allow_delivery,
    p_buy_currency_id: payload.buy_currency_id ?? null,
    p_sell_currency_id: payload.sell_currency_id ?? null,
    p_pricing_method: payload.pricing_method ?? null,
    p_markup_percentage: payload.markup_percentage ?? 0,
    p_quantity_display_mode: payload.quantity_display_mode ?? null,
    p_default_print_charge_amount: (payload as any).default_print_charge_amount ?? 0,
    p_default_packing_charge_amount: (payload as any).default_packing_charge_amount ?? 0,
    p_deduct_charges_from_margin: payload.deduct_charges_from_margin ?? false,
    p_vendor_filters: payload.vendor_filters ?? null,
    p_deduct_print_from_margin: (payload as any).deduct_print_from_margin ?? false,
    p_deduct_packing_from_margin: (payload as any).deduct_packing_from_margin ?? false,
  });

  if (error) {
    throw error;
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Shop was not saved.');
  }

  return (Array.isArray(data) ? data[0] : data) as Shop;
};

const browseShopCatalog = async (
  shopSlug: string,
  opts: {
    search?: string | null;
    category?: string | null;
    brand?: string | null;
    limit?: number;
    offset?: number;
  } = {},
): Promise<any> => {
  const { data, error } = await supabase.rpc('browse_shop_catalog', {
    p_shop_slug: shopSlug,
    p_search: opts.search ?? null,
    p_category: opts.category ?? null,
    p_brand: opts.brand ?? null,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
  });

  if (error) {
    throw error;
  }

  return data;
};

export type CustomerAccessibleShop = {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: string;
  order_mode: string;
  is_negotiable: boolean;
  see_price: boolean;
};

const listShopsForCustomer = async (
  tenantId?: number | null,
): Promise<CustomerAccessibleShop[]> => {
  const { data, error } = await supabase.rpc('list_shops_for_customer', {
    p_tenant_id: tenantId ?? null,
  });

  if (error) {
    throw error;
  }

  return (data as CustomerAccessibleShop[] | null) ?? [];
};

// ---- Order Management RPCs (P7) ---------------------------------------

const submitShopOrderFromCart = async (
  cartId: number,
  recipientName: string,
  recipientPhone: string,
  shippingAddress: string,
  billingProfileId: number | null,
  isPrepaid?: boolean,
  deliveryInstructions?: string | null,
  codChargeAmount?: number,
  deliveryChargeAmount?: number,
  printChargeAmount?: number,
  packingChargeAmount?: number,
  discountAmount?: number,
  recipientPhoneSecondary?: string | null,
  shippingDistrict?: string | null,
  shippingThana?: string | null,
): Promise<{ order_id: number; order_no: string; status: string }> => {
  const { data, error } = await supabase.rpc('submit_shop_order_from_cart', {
    p_cart_id: cartId,
    p_recipient_name: recipientName,
    p_recipient_phone: recipientPhone,
    p_shipping_address: shippingAddress,
    p_recipient_phone_secondary: recipientPhoneSecondary ?? null,
    p_shipping_district: shippingDistrict ?? null,
    p_shipping_thana: shippingThana ?? null,
    p_billing_profile_id: billingProfileId || null,
    p_is_prepaid: isPrepaid ?? false,
    p_delivery_instructions: deliveryInstructions ?? null,
    p_cod_charge_amount: codChargeAmount ?? 0,
    p_delivery_charge_amount: deliveryChargeAmount ?? 0,
    p_print_charge_amount: printChargeAmount ?? 0,
    p_packing_charge_amount: packingChargeAmount ?? 0,
    p_discount_amount: discountAmount ?? 0,
  });

  if (error) throw error;
  return data as { order_id: number; order_no: string; status: string };
};

const staffPriceShopOrder = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_price_shop_order', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
};

const customerCounterOffer = async (
  orderId: number,
  items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('customer_counter_offer', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
};

const staffCounterOffer = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_counter_offer', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
};

const confirmShopOrder = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('confirm_shop_order', {
    p_order_id: orderId,
  });
  if (error) throw error;
};

const listShopOrdersForCustomer = async (
  shopId: number,
  opts: { limit?: number; offset?: number } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_shop_orders_for_customer', {
    p_shop_id: shopId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
  });
  if (error) throw error;
  return (data as ShopOrder[] | null) ?? [];
};

const listShopOrdersForStaff = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; search?: string | null; status?: string | null; shopId?: number | null } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_shop_orders_for_staff', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
    p_search: opts.search ?? null,
    p_status: opts.status ?? null,
    p_shop_id: opts.shopId ?? null,
  });
  if (error) throw error;
  return (data as ShopOrder[] | null) ?? [];
};

const listDropshipShopOrdersForStaff = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; search?: string | null; status?: string | null } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_dropship_shop_orders_for_staff', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
  });
  if (error) throw error;
  return (data as ShopOrder[] | null) ?? [];
};

const getShopOrderById = async (
  orderId: number,
): Promise<{ order: ShopOrder; items: ShopOrderItem[] }> => {
  const { data: order, error: orderErr } = await supabase
    .from('shop_orders')
    .select('*')
    .eq('id', orderId)
    .single();

  if (orderErr) throw orderErr;

  const { data: items, error: itemsErr } = await supabase
    .from('shop_order_items')
    .select('*')
    .eq('order_id', orderId);

  if (itemsErr) throw itemsErr;

  return {
    order: order as ShopOrder,
    items: (items as ShopOrderItem[] | null) ?? [],
  };
};

const placeShopOrderForProcurement = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('place_shop_order_for_procurement', {
    p_order_id: orderId,
  });
  if (error) throw error;
};

const fulfillShopOrderToInvoice = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('fulfill_shop_order_to_invoice', {
    p_order_id: orderId,
  });
  if (error) throw error;
};

const updateOrderCharges = async (
  orderId: number,
  payload: {
    delivery_charge_amount: number;
    deduct_delivery_from_margin: boolean;
    cod_charge_amount: number;
    deduct_cod_from_margin: boolean;
    print_charge_amount: number;
    deduct_print_from_margin: boolean;
    packing_charge_amount: number;
    deduct_packing_from_margin: boolean;
  },
): Promise<void> => {
  const { error } = await supabase
    .from('shop_orders')
    .update(payload)
    .eq('id', orderId);
  if (error) throw error;
};

const deleteShopOrder = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('delete_shop_order', {
    p_order_id: orderId,
  });
  if (error) throw error;
};

const processDropshipShopOrder = async (orderId: number): Promise<{ success: boolean; order_id?: number; new_status?: string; error?: string }> => {
  const { data, error } = await supabase.rpc('process_dropship_shop_order', {
    p_order_id: orderId,
  });
  if (error) throw error;
  return data as { success: boolean; order_id?: number; new_status?: string; error?: string };
};

const fetchCustomerShopCategories = async (
  tenantId: number,
): Promise<{ name: string; count: number }[]> => {
  const { data, error } = await supabase.rpc('fetch_customer_shop_categories', {
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }

  return (data as { name: string; count: number }[] | null) ?? [];
};

export const shopOrderRepository = {
  listShops,
  upsertShop,
  browseShopCatalog,
  listShopsForCustomer,
  fetchCustomerShopCategories,
  submitShopOrderFromCart,
  staffPriceShopOrder,
  customerCounterOffer,
  staffCounterOffer,
  confirmShopOrder,
  listShopOrdersForCustomer,
  listShopOrdersForStaff,
  listDropshipShopOrdersForStaff,
  getShopOrderById,
  placeShopOrderForProcurement,
  fulfillShopOrderToInvoice,
  deleteShopOrder,
  updateOrderCharges,
  processDropshipShopOrder,
};

