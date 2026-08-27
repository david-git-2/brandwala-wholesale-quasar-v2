import { supabase } from 'src/boot/supabase';
import type {
  Shop,
  CreateShopPayload,
  UpdateShopPayload,
  ShopOrder,
  ShopOrderItem,
  ShopCatalogBrowseResult,
  ShopCatalogSearchResult,
  ShopCatalogProductDetailResult,
  ShopCatalogRelatedResult,
  CustomerOrderListItem,
  CustomerOrderDetail,
} from '../types';
import type { StaffShopOrderDetailResponse } from '../types/staffShopOrderDetail';
import {
  mapStaffShopOrderDetailToFlat,
  parseStaffShopOrderDetailResponse,
} from '../utils/staffShopOrderDetailMapper';
import { mapDropshipOrderDetailV2Response } from '../utils/dropshipOrderDetailV2Mapper';
import { mapDropshipManagementOrderResponse } from '../utils/dropshipManagementOrderMapper';
import type {
  DropshipCourierBankTransferPayload,
  DropshipManagementOrderView,
  DropshipSettlementDraftPayload,
} from '../types/dropshipManagementOrder';

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

const SHOP_DETAIL_SELECT =
  'id, tenant_id, name, slug, shop_type, vendor_code, order_mode, is_negotiable, show_stock_quantity, default_currency_id, global_stock_type_id, is_active, allow_delivery, buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode, default_print_charge_amount, default_packing_charge_amount, deduct_charges_from_margin, vendor_filters, deduct_print_from_margin, deduct_packing_from_margin, description, category_ids, created_at, updated_at';

const getShop = async (shopId: number, tenantId: number): Promise<Shop> => {
  const { data, error } = await supabase
    .from('shops')
    .select(SHOP_DETAIL_SELECT)
    .eq('id', shopId)
    .eq('tenant_id', tenantId)
    .is('deleted_at', null)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('Shop not found.');
  return data as Shop;
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
    p_vendor_code: payload.vendor_code?.trim() || null,
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
  tenantId: number,
  shopSlug: string,
  opts: {
    search?: string | null;
    category?: string | null;
    brand?: string | null;
    limit?: number;
    offset?: number;
  } = {},
): Promise<ShopCatalogBrowseResult> => {
  const { data, error } = await supabase.rpc('browse_shop_catalog_for_customer', {
    p_tenant_id: tenantId,
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

  const payload = (data ?? {}) as ShopCatalogBrowseResult;
  return {
    data: payload.data ?? [],
    meta: payload.meta ?? {
      total: 0,
      page: 1,
      page_size: opts.limit ?? 20,
      total_pages: 1,
    },
  };
};

const searchShopCatalog = async (
  tenantId: number,
  search: string,
  opts: { limit?: number; offset?: number } = {},
): Promise<ShopCatalogSearchResult> => {
  const { data, error } = await supabase.rpc('search_shop_catalog_for_customer', {
    p_tenant_id: tenantId,
    p_search: search,
    p_limit: opts.limit ?? 15,
    p_offset: opts.offset ?? 0,
  });

  if (error) {
    throw error;
  }

  const payload = (data ?? {}) as ShopCatalogSearchResult;
  return {
    data: payload.data ?? [],
    meta: payload.meta ?? {
      total: 0,
      page: 1,
      page_size: opts.limit ?? 15,
      total_pages: 1,
    },
  };
};

const getShopCatalogProduct = async (
  tenantId: number,
  shopSlug: string,
  productId: number,
): Promise<ShopCatalogProductDetailResult> => {
  const { data, error } = await supabase.rpc('get_shop_catalog_product_for_customer', {
    p_tenant_id: tenantId,
    p_shop_slug: shopSlug,
    p_product_id: productId,
  });

  if (error) {
    throw error;
  }

  const payload = (data ?? {}) as ShopCatalogProductDetailResult;
  if (!payload.data) {
    throw new Error('Product not found.');
  }

  return payload;
};

const listRelatedShopCatalogProducts = async (
  tenantId: number,
  shopSlug: string,
  productId: number,
  limit = 4,
): Promise<ShopCatalogRelatedResult> => {
  const { data, error } = await supabase.rpc('list_related_shop_catalog_products_for_customer', {
    p_tenant_id: tenantId,
    p_shop_slug: shopSlug,
    p_product_id: productId,
    p_limit: limit,
  });

  if (error) {
    throw error;
  }

  const payload = (data ?? {}) as ShopCatalogRelatedResult;
  return {
    data: payload.data ?? [],
    meta: {
      category: payload.meta?.category ?? null,
    },
  };
};

export type CustomerAccessibleShop = {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: string;
  order_mode: string;
  is_negotiable: boolean;
  can_see_buy_price: boolean;
  can_see_sell_price: boolean;
  description?: string | null;
  category_ids?: number[] | null;
  categories?: Array<{ id: number; name: string; slug: string; icon: string }> | null;
  sell_currency_id?: number | null;
  sell_currency_code?: string | null;
  sell_currency_symbol?: string | null;
};

const listCustomerShops = async (tenantId: number): Promise<CustomerAccessibleShop[]> => {
  const { data, error } = await supabase.rpc('list_customer_shops', {
    p_tenant_id: tenantId,
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
    is_first_offer_manual?: boolean | null;
    weight_kg?: number | null;
    cbm?: number | null;
    cost_price_amount?: number | null;
    product_id?: number | null;
    product_weight_gm?: number | null;
    package_weight_gm?: number | null;
  }>,
  profitBasis?: string | null,
  rates?: {
    conversion_rate?: number | null;
    cargo_rate?: number | null;
    profit_rate?: number | null;
  },
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('staff_price_shop_order', {
    p_order_id: orderId,
    p_items: items,
    p_profit_basis: profitBasis ?? null,
    p_fx_rate: rates?.conversion_rate ?? null,
    p_cargo_rate: rates?.cargo_rate ?? null,
    p_profit_pct: rates?.profit_rate ?? null,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
};

const staffFinalizeCatalogPrices = async (
  orderId: number,
  items: Array<{ id: number; final_offer_amount: number; final_offer_currency_id: number }>,
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('staff_finalize_catalog_prices', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
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

const listCustomerShopOrders = async (
  tenantId: number,
  opts: { limit?: number; offset?: number; statusBucket?: string | null } = {},
): Promise<CustomerOrderListItem[]> => {
  const { data, error } = await supabase.rpc('list_customer_shop_orders', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
    p_status_bucket: opts.statusBucket ?? null,
  });
  if (error) throw error;
  return (data as CustomerOrderListItem[] | null) ?? [];
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
  opts: {
    limit?: number;
    offset?: number;
    search?: string | null;
    status?: string | null;
    statuses?: string[] | null;
  } = {},
): Promise<ShopOrder[]> => {
  const { data, error } = await supabase.rpc('list_dropship_shop_orders_for_staff', {
    p_tenant_id: tenantId,
    p_limit: opts.limit ?? 20,
    p_offset: opts.offset ?? 0,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
    p_statuses: opts.statuses ?? null,
  });
  if (error) throw error;
  return (data as ShopOrder[] | null) ?? [];
};

const getShopOrderById = async (
  tenantId: number,
  orderId: number,
): Promise<{
  order: ShopOrder & { shop_sell_currency_id?: number | null; shop_buy_currency_id?: number | null };
  items: ShopOrderItem[];
}> => {
  const { data, error } = await supabase.rpc('get_shop_order_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
  });
  if (error) throw error;

  return mapStaffShopOrderDetailToFlat(parseStaffShopOrderDetailResponse(data));
};

const getDropshipOrderDetailV2 = async (tenantId: number, orderId: number) => {
  const { data, error } = await supabase.rpc('get_dropship_order_detail_v2', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
  });
  if (error) throw error;

  return mapDropshipOrderDetailV2Response(data);
};

const getDropshipManagementOrder = async (
  tenantId: number,
  orderId: number,
): Promise<DropshipManagementOrderView> => {
  const { data, error } = await supabase.rpc('get_dropship_management_order', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
  });
  if (error) throw error;
  return mapDropshipManagementOrderResponse(data);
};

const saveDropshipSettlementDraft = async (
  tenantId: number,
  orderId: number,
  payload: DropshipSettlementDraftPayload,
) => {
  const { data, error } = await supabase.rpc('save_dropship_settlement_draft', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload,
  });
  if (error) throw error;
  return data;
};

const markDropshipOrderDelivered = async (
  tenantId: number,
  orderId: number,
  payload: DropshipSettlementDraftPayload,
) => {
  const { data, error } = await supabase.rpc('mark_dropship_order_delivered', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload,
  });
  if (error) throw error;
  return data;
};

const recordDropshipCourierBankTransfer = async (
  tenantId: number,
  orderId: number,
  payload: DropshipCourierBankTransferPayload,
) => {
  const { data, error } = await supabase.rpc('record_dropship_courier_bank_transfer', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload,
  });
  if (error) throw error;
  return data;
};

const transferDropshipResellerProfit = async (
  tenantId: number,
  orderId: number,
  payload?: DropshipSettlementDraftPayload,
) => {
  const { data, error } = await supabase.rpc('transfer_dropship_reseller_profit', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload ?? {},
  });
  if (error) throw error;
  return data;
};

export type SaveDropshipProcessingDeskInput = {
  tenantId: number;
  orderId: number;
  order: ShopOrder;
  summary: {
    delivery_charge_amount: number;
    deduct_delivery_from_margin: boolean;
    cod_charge_amount: number;
    deduct_cod_from_margin: boolean;
    print_charge_amount: number;
    deduct_print_from_margin: boolean;
    packing_charge_amount: number;
    deduct_packing_from_margin: boolean;
    discount_amount: number;
    cod_collect_amount: number;
  };
  pickup: {
    sender_name: string;
    pickup_phone: string;
    pickup_address: string;
  };
  courier: {
    courier_service_id: string | null;
    courier_awb_number: string;
    tracking_url: string;
    allow_open_box: boolean;
  };
  deliveredQuantities: Record<number, number>;
  deliveryZone: 'inside_dhaka' | 'outside_dhaka';
};

const saveDropshipProcessingDesk = async (input: SaveDropshipProcessingDeskInput): Promise<void> => {
  const {
    tenantId,
    orderId,
    order,
    summary,
    pickup,
    courier,
    deliveredQuantities,
    deliveryZone,
  } = input;

  const { error: chargesError } = await supabase.rpc('update_shop_order_charges_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: {
      delivery_charge_amount: summary.delivery_charge_amount,
      deduct_delivery_from_margin: summary.deduct_delivery_from_margin,
      cod_charge_amount: summary.cod_charge_amount,
      deduct_cod_from_margin: summary.deduct_cod_from_margin,
      print_charge_amount: summary.print_charge_amount,
      deduct_print_from_margin: summary.deduct_print_from_margin,
      packing_charge_amount: summary.packing_charge_amount,
      deduct_packing_from_margin: summary.deduct_packing_from_margin,
    },
  });
  if (chargesError) throw chargesError;

  const { error: orderError } = await supabase
    .from('shop_orders')
    .update({
      discount_amount: summary.discount_amount,
      cod_collect_amount: summary.cod_collect_amount,
      updated_at: new Date().toISOString(),
    })
    .eq('id', orderId)
    .eq('tenant_id', tenantId);
  if (orderError) throw orderError;

  const { error: consignmentError } = await supabase.rpc('update_dropship_consignment', {
    p_order_id: orderId,
    p_cod_collect_amount: summary.cod_collect_amount,
    p_package_weight_band: order.package_weight_band ?? 'under_1kg',
    p_delivery_zone: deliveryZone,
    p_sender_name: pickup.sender_name,
    p_pickup_phone: pickup.pickup_phone,
    p_pickup_address: pickup.pickup_address,
    p_allow_open_box: courier.allow_open_box,
    p_courier_service_id: courier.courier_service_id,
    p_courier_awb_number: courier.courier_awb_number,
    p_tracking_url: courier.tracking_url,
    p_courier_tracking_number: courier.courier_awb_number,
    p_courier_cost_amount: summary.delivery_charge_amount,
    p_delivery_charge_amount: summary.delivery_charge_amount,
    p_cod_charge_amount: summary.cod_charge_amount,
    p_courier_order_ref: order.order_no,
    p_recipient_name: order.recipient_name,
    p_recipient_phone: order.recipient_phone,
    p_recipient_phone_secondary: order.recipient_phone_secondary,
    p_shipping_address: order.shipping_address,
    p_shipping_district: order.shipping_district,
    p_shipping_thana: order.shipping_thana,
  });
  if (consignmentError) throw consignmentError;

  const itemUpdates = Object.entries(deliveredQuantities).map(([itemId, quantity]) =>
    supabase
      .from('shop_order_items')
      .update({
        confirmed_quantity: quantity,
        updated_at: new Date().toISOString(),
      })
      .eq('id', Number(itemId))
      .eq('order_id', orderId),
  );

  const itemResults = await Promise.all(itemUpdates);
  const itemError = itemResults.find((result) => result.error)?.error;
  if (itemError) throw itemError;
};

const getCustomerShopOrder = async (
  tenantId: number,
  orderId: number,
): Promise<CustomerOrderDetail> => {
  const { data, error } = await supabase.rpc('get_customer_shop_order', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
  });
  if (error) throw error;

  const payload = data as { order?: CustomerOrderDetail['order']; items?: ShopOrderItem[] } | null;
  if (!payload?.order) {
    throw new Error('Order not found');
  }

  const items: ShopOrderItem[] = (payload.items ?? []).map((item) => ({
    ...item,
    final_offer_amount: item.final_offer_amount ?? item.final_price_amount ?? null,
    procurement_pulled: item.procurement_pulled ?? false,
    returned_quantity: item.returned_quantity ?? 0,
  }));

  return { order: payload.order, items };
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
  tenantId: number,
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
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('update_shop_order_charges_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
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

const updateOrderStatus = async (
  tenantId: number,
  orderId: number,
  status: string,
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('update_shop_order_status_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_status: status,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
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
  tenantId: number,
  orderId: number,
  payload: {
    conversion_rate?: number | null;
    cargo_rate?: number | null;
    profit_rate?: number | null;
    first_offer_rate?: number | null;
    final_offer_rate?: number | null;
    profit_basis?: 'purchase' | 'total_cost' | null;
  },
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('update_catalog_order_rates_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_payload: payload,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
};

const staffStartCatalogProcurement = async (orderId: number): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('staff_start_catalog_procurement', {
    p_order_id: orderId,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
};

const staffSetCatalogOrderedQty = async (
  orderId: number,
  items: Array<{ id: number; ordered_quantity: number }>,
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('staff_set_catalog_ordered_qty', {
    p_order_id: orderId,
    p_items: items,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
};

const staffSetCatalogDeliveredQty = async (
  orderId: number,
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('staff_set_catalog_delivered_qty', {
    p_order_id: orderId,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
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

const updateCatalogOrderItemForStaff = async (
  tenantId: number,
  orderId: number,
  itemId: number,
  payload: {
    product_weight_gm?: number | null;
    package_weight_gm?: number | null;
    weight_kg?: number | null;
    cost_price_amount?: number | null;
    staff_offer_amount?: number | null;
    is_first_offer_manual?: boolean | null;
    final_price_amount?: number | null;
    is_final_offer_manual?: boolean | null;
    customer_offer_amount?: number | null;
    customer_offer_currency_id?: number | null;
    confirmed_quantity?: number | null;
    quantity?: number | null;
  },
): Promise<StaffShopOrderDetailResponse> => {
  const { data, error } = await supabase.rpc('update_catalog_order_item_for_staff', {
    p_tenant_id: tenantId,
    p_order_id: orderId,
    p_item_id: itemId,
    p_payload: payload,
  });
  if (error) throw error;
  return parseStaffShopOrderDetailResponse(data);
};

/** Customer-scope inline edits (shop RLS). Staff catalog edits use updateCatalogOrderItemForStaff. */
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
    is_first_offer_manual?: boolean | null;
    final_price_amount?: number | null;
    is_final_offer_manual?: boolean | null;
    customer_offer_amount?: number | null;
    customer_offer_currency_id?: number | null;
    confirmed_quantity?: number | null;
    quantity?: number | null;
  },
): Promise<void> => {
  const itemUpdates: Record<string, any> = {};
  if (payload.weight_kg !== undefined) itemUpdates.weight_kg = payload.weight_kg;
  if (payload.cost_price_amount !== undefined) itemUpdates.cost_price_amount = payload.cost_price_amount;
  if (payload.staff_offer_amount !== undefined) itemUpdates.staff_offer_amount = payload.staff_offer_amount;
  if (payload.is_first_offer_manual !== undefined) itemUpdates.is_first_offer_manual = payload.is_first_offer_manual;
  if (payload.customer_offer_amount !== undefined) itemUpdates.customer_offer_amount = payload.customer_offer_amount;
  if (payload.customer_offer_currency_id !== undefined) itemUpdates.customer_offer_currency_id = payload.customer_offer_currency_id;
  if (payload.final_price_amount !== undefined) itemUpdates.final_price_amount = payload.final_price_amount;
  if (payload.is_final_offer_manual !== undefined) itemUpdates.is_final_offer_manual = payload.is_final_offer_manual;
  if (payload.confirmed_quantity !== undefined) itemUpdates.confirmed_quantity = payload.confirmed_quantity;
  if (payload.quantity !== undefined) itemUpdates.quantity = payload.quantity;

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
  getShop,
  upsertShop,
  deleteShop,
  updateShopExtraAttributes,
  browseShopCatalog,
  searchShopCatalog,
  getShopCatalogProduct,
  listRelatedShopCatalogProducts,
  listCustomerShops,
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
  listCustomerShopOrders,
  listShopOrdersForStaff,
  listDropshipShopOrdersForStaff,
  getShopOrderById,
  getDropshipOrderDetailV2,
  getDropshipManagementOrder,
  saveDropshipSettlementDraft,
  markDropshipOrderDelivered,
  recordDropshipCourierBankTransfer,
  transferDropshipResellerProfit,
  saveDropshipProcessingDesk,
  getCustomerShopOrder,
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
  updateCatalogOrderItemForStaff,
};




