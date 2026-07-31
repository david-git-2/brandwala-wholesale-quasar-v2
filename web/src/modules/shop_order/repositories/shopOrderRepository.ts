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
    p_description: payload.description?.trim() || null,
    p_category_ids: payload.category_ids ?? [],
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
  description?: string | null;
  category_ids?: number[] | null;
  categories?: Array<{ id: number; name: string; slug: string; icon: string }> | null;
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
  items: Array<{
    id: number;
    staff_offer_amount: number;
    staff_offer_currency_id: number;
    weight_kg?: number | null;
    cbm?: number | null;
    cost_price_amount?: number | null;
    product_id?: number | null;
    product_weight_gm?: number | null;
    package_weight_gm?: number | null;
  }>,
  profitBasis?: string | null,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_price_shop_order', {
    p_order_id: orderId,
    p_items: items,
    p_profit_basis: profitBasis ?? null,
  });
  if (error) throw error;

  // Sync updated price/unit (reference_cost_amount), product_weight, and package_weight back to products table
  const { data: orderItemRows } = await supabase
    .from('shop_order_items')
    .select('id, product_id, weight_kg')
    .eq('order_id', orderId);

  if (orderItemRows && orderItemRows.length > 0) {
    const itemMap = new Map(items.map((i) => [i.id, i]));
    for (const itemRow of orderItemRows) {
      const payloadItem = itemMap.get(itemRow.id);
      const productId = itemRow.product_id || payloadItem?.product_id;
      if (!productId) continue;

      const productUpdates: Record<string, any> = {};
      if (payloadItem?.product_weight_gm !== undefined && payloadItem.product_weight_gm !== null && payloadItem.product_weight_gm > 0) {
        productUpdates.product_weight = payloadItem.product_weight_gm;
      }
      if (payloadItem?.package_weight_gm !== undefined && payloadItem.package_weight_gm !== null && payloadItem.package_weight_gm > 0) {
        productUpdates.package_weight = payloadItem.package_weight_gm;
      }

      if (Object.keys(productUpdates).length > 0) {
        await supabase
          .from('products')
          .update(productUpdates)
          .eq('id', productId);
      }
    }
  }
};

const staffFinalizeCatalogPrices = async (
  orderId: number,
  items: Array<{ id: number; final_offer_amount: number; final_offer_currency_id: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_finalize_catalog_prices', {
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

const customerConfirmShopOrder = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('customer_confirm_shop_order', {
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
): Promise<{
  order: ShopOrder & { shop_sell_currency_id?: number | null; shop_buy_currency_id?: number | null };
  items: ShopOrderItem[];
}> => {
  const { data: orderRow, error: orderErr } = await supabase
    .from('shop_orders')
    .select('*, customer_groups(name), shops(sell_currency_id, buy_currency_id)')
    .eq('id', orderId)
    .single();

  if (orderErr) throw orderErr;

  const order: ShopOrder & { shop_sell_currency_id?: number | null; shop_buy_currency_id?: number | null } = {
    ...orderRow,
    customer_group_name: (orderRow as any).customer_groups?.name ?? orderRow.customer_group_name,
    shop_sell_currency_id: (orderRow as any).shops?.sell_currency_id ?? null,
    shop_buy_currency_id: (orderRow as any).shops?.buy_currency_id ?? null,
  };
  delete (order as any).customer_groups;
  delete (order as any).shops;

  // Fallback until shop_orders.collection_source is migrated / populated
  if (!order.collection_source && order.global_invoice_id) {
    const { data: inv } = await supabase
      .from('global_invoices')
      .select('collection_source')
      .eq('id', order.global_invoice_id)
      .maybeSingle();
    if (inv?.collection_source) {
      order.collection_source = inv.collection_source;
    }
  } else if (!order.collection_source && order.is_prepaid_snapshot) {
    order.collection_source = 'billing_profile';
  }

  const { data: rawItems, error: itemsErr } = await supabase
    .from('shop_order_items')
    .select('*, products(product_code, brand, barcode, product_weight, package_weight, reference_cost_amount)')
    .eq('order_id', orderId);

  if (itemsErr) throw itemsErr;

  const items: ShopOrderItem[] = (rawItems || []).map((row: any) => {
    const sku = row.products?.product_code ?? null;
    const brand = row.products?.brand ?? null;
    const barcode = row.products?.barcode ?? null;
    const product_weight_gm = row.products?.product_weight ?? null;
    const package_weight_gm = row.products?.package_weight ?? null;
    const cost_price_amount =
      row.cost_price_amount ??
      row.unit_list_price_amount ??
      row.products?.reference_cost_amount ??
      null;
    const item = {
      ...row,
      cost_price_amount,
      sku,
      brand,
      barcode,
      product_weight_gm,
      package_weight_gm,
    };
    delete item.products;
    return item as ShopOrderItem;
  });

  return {
    order,
    items,
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

const updateShopExtraAttributes = async (
  shopId: number,
  tenantId: number,
  description: string | null,
  categoryIds: number[],
): Promise<void> => {
  const { error } = await supabase
    .from('shops')
    .update({
      description,
      category_ids: categoryIds,
      updated_at: new Date().toISOString(),
    })
    .eq('id', shopId)
    .eq('tenant_id', tenantId);

  if (error) {
    throw error;
  }
};

const deleteShop = async (shopId: number, tenantId: number): Promise<void> => {
  const { error } = await supabase.rpc('delete_shop', {
    p_shop_id: shopId,
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }
};

const updateOrderStatus = async (orderId: number, status: string): Promise<void> => {
  const { error } = await supabase
    .from('shop_orders')
    .update({ status })
    .eq('id', orderId);
  if (error) throw error;
};

const getShopCurrencies = async (
  shopId: number,
): Promise<{ sell_currency_id: number | null; buy_currency_id: number | null }> => {
  const { data, error } = await supabase
    .from('shops')
    .select('sell_currency_id, buy_currency_id')
    .eq('id', shopId)
    .maybeSingle();
  if (error) return { sell_currency_id: null, buy_currency_id: null };
  return {
    sell_currency_id: data?.sell_currency_id ?? null,
    buy_currency_id: data?.buy_currency_id ?? null,
  };
};

const getShopSellCurrencyId = async (shopId: number): Promise<number | null> => {
  const currencies = await getShopCurrencies(shopId);
  return currencies.sell_currency_id;
};

const updateCatalogOrderRates = async (
  orderId: number,
  payload: {
    conversion_rate?: number | null;
    cargo_rate?: number | null;
    profit_rate?: number | null;
    profit_basis?: 'purchase' | 'total_cost' | null;
  },
): Promise<void> => {
  const { error } = await supabase
    .from('shop_orders')
    .update(payload)
    .eq('id', orderId);
  if (error) throw error;
};

const staffStartCatalogProcurement = async (orderId: number): Promise<void> => {
  const { error } = await supabase.rpc('staff_start_catalog_procurement', {
    p_order_id: orderId,
  });
  if (error) throw error;
};

const staffSetCatalogOrderedQty = async (
  orderId: number,
  items: Array<{ id: number; ordered_quantity: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_set_catalog_ordered_qty', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
};

const staffSetCatalogDeliveredQty = async (
  orderId: number,
  items: Array<{ id: number; delivered_quantity: number }>,
): Promise<void> => {
  const { error } = await supabase.rpc('staff_set_catalog_delivered_qty', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
};

const listCustomerOrderBacklogItems = async (
  tenantId: number,
  billingProfileId: number,
): Promise<any[]> => {
  const { data, error } = await supabase.rpc('list_customer_order_backlog_items', {
    p_tenant_id: tenantId,
    p_billing_profile_id: billingProfileId,
  });
  if (error) throw error;
  return (data as any[] | null) ?? [];
};

const updateCatalogOrderItem = async (
  orderId: number,
  itemId: number,
  productId: number | null,
  payload: {
    product_weight_gm?: number | null;
    package_weight_gm?: number | null;
    weight_kg?: number | null;
    cost_price_amount?: number | null;
    staff_offer_amount?: number | null;
    final_price_amount?: number | null;
    ordered_quantity?: number | null;
    delivered_quantity?: number | null;
  },
): Promise<void> => {
  const itemUpdates: Record<string, any> = {};
  if (payload.weight_kg !== undefined) itemUpdates.weight_kg = payload.weight_kg;
  if (payload.cost_price_amount !== undefined) itemUpdates.cost_price_amount = payload.cost_price_amount;
  if (payload.staff_offer_amount !== undefined) itemUpdates.staff_offer_amount = payload.staff_offer_amount;
  if (payload.final_price_amount !== undefined) itemUpdates.final_price_amount = payload.final_price_amount;
  if (payload.ordered_quantity !== undefined) itemUpdates.ordered_quantity = payload.ordered_quantity;
  if (payload.delivered_quantity !== undefined) itemUpdates.delivered_quantity = payload.delivered_quantity;

  if (Object.keys(itemUpdates).length > 0) {
    const { error: itemErr } = await supabase
      .from('shop_order_items')
      .update(itemUpdates)
      .eq('id', itemId);
    if (itemErr) throw itemErr;
  }

  if (productId) {
    const productUpdates: Record<string, any> = {};
    if (payload.product_weight_gm !== undefined && payload.product_weight_gm !== null && payload.product_weight_gm > 0) {
      productUpdates.product_weight = payload.product_weight_gm;
    }
    if (payload.package_weight_gm !== undefined && payload.package_weight_gm !== null && payload.package_weight_gm > 0) {
      productUpdates.package_weight = payload.package_weight_gm;
    }

    if (Object.keys(productUpdates).length > 0) {
      const { error: prodErr } = await supabase
        .from('products')
        .update(productUpdates)
        .eq('id', productId);
      if (prodErr) throw prodErr;
    }
  }
};

export const shopOrderRepository = {
  listShops,
  upsertShop,
  deleteShop,
  updateShopExtraAttributes,
  browseShopCatalog,
  listShopsForCustomer,
  fetchCustomerShopCategories,
  submitShopOrderFromCart,
  staffPriceShopOrder,
  staffFinalizeCatalogPrices,
  customerCounterOffer,
  staffCounterOffer,
  confirmShopOrder,
  customerConfirmShopOrder,
  staffStartCatalogProcurement,
  staffSetCatalogOrderedQty,
  staffSetCatalogDeliveredQty,
  listCustomerOrderBacklogItems,
  listShopOrdersForCustomer,
  listShopOrdersForStaff,
  listDropshipShopOrdersForStaff,
  getShopOrderById,
  placeShopOrderForProcurement,
  fulfillShopOrderToInvoice,
  deleteShopOrder,
  updateOrderCharges,
  processDropshipShopOrder,
  updateOrderStatus,
  getShopCurrencies,
  getShopSellCurrencyId,
  updateCatalogOrderRates,
  updateCatalogOrderItem,
};




