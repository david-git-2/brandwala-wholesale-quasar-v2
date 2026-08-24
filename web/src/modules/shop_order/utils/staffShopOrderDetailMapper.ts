import type { ShopOrder, ShopOrderItem } from '../types';
import type {
  StaffOrderMoney,
  StaffOrderOffer,
  StaffShopOrderDetailItem,
  StaffShopOrderDetailOrder,
  StaffShopOrderDetailResponse,
} from '../types/staffShopOrderDetail';

function moneyAmount(m: StaffOrderMoney | null | undefined): number | null {
  return m?.amount ?? null;
}

function moneyCurrencyId(m: StaffOrderMoney | null | undefined): number | null {
  return m?.currency?.id ?? null;
}

function offerAmount(o: StaffOrderOffer | null | undefined): number | null {
  return o?.amount ?? null;
}

function offerCurrencyId(o: StaffOrderOffer | null | undefined): number | null {
  return o?.currency?.id ?? null;
}

export function mapStaffShopOrderDetailToFlat(
  payload: StaffShopOrderDetailResponse,
): { order: ShopOrder; items: ShopOrderItem[] } {
  const o = payload.order;
  const shop = o.shop;
  const customer = o.customer;
  const status = o.status;
  const rates = o.rates;
  const recipient = o.recipient;
  const charges = o.charges;
  const deduct = charges.deduct_from_margin;
  const totals = o.totals;
  const courier = o.courier as Record<string, unknown>;
  const pickup = o.pickup as Record<string, unknown>;
  const payout = o.payout as Record<string, unknown>;
  const parcel = o.parcel as Record<string, unknown>;
  const returnInfo = o.return_info as Record<string, unknown>;

  const order = {
    id: o.id,
    tenant_id: o.tenant_id,
    shop_id: shop.id,
    shop_name: shop.name ?? undefined,
    customer_group_id: customer.group_id,
    customer_group_name: customer.group_name ?? undefined,
    cart_id: o.cart_id,
    order_no: o.order_no,
    name: o.name,
    shop_type_snapshot: shop.type as ShopOrder['shop_type_snapshot'],
    order_mode_snapshot: shop.order_mode as ShopOrder['order_mode_snapshot'],
    is_negotiable_snapshot: shop.is_negotiable,
    status: status.value as ShopOrder['status'],
    negotiate_round: status.negotiate_round,
    cargo_rate: rates.cargo,
    conversion_rate: rates.conversion,
    profit_rate: rates.profit,
    first_offer_rate: rates.first_offer,
    final_offer_rate: rates.final_offer,
    profit_basis: (rates.profit_basis as ShopOrder['profit_basis']) ?? null,
    package_weight_kg: rates.package_weight_kg,
    recipient_name: recipient.name,
    recipient_phone: recipient.phone,
    recipient_phone_secondary: recipient.phone_secondary,
    shipping_address: recipient.address,
    shipping_district: recipient.district,
    shipping_thana: recipient.thana,
    recipient_profile_id: recipient.profile_id,
    billing_profile_id: recipient.billing_profile_id,
    placed_at: o.placed_at,
    fulfilled_at: o.fulfilled_at,
    global_invoice_id: o.global_invoice_id,
    shop_sell_currency_id: shop.sell_currency?.id ?? null,
    shop_buy_currency_id: shop.buy_currency?.id ?? null,
    shop_sell_currency_symbol: shop.sell_currency?.symbol ?? null,
    shop_buy_currency_symbol: shop.buy_currency?.symbol ?? null,
    created_by_email: o.created_by_email,
    created_at: o.created_at,
    updated_at: o.updated_at,
    cod_charge_amount: charges.cod,
    delivery_charge_amount: charges.delivery,
    print_charge_amount: charges.print,
    packing_charge_amount: charges.packing,
    discount_amount: charges.discount,
    is_prepaid_snapshot: recipient.is_prepaid,
    delivery_instructions: recipient.delivery_instructions,
    deduct_charges_from_margin: deduct.charges,
    deduct_cod_from_margin: deduct.cod,
    deduct_delivery_from_margin: deduct.delivery,
    deduct_print_from_margin: deduct.print,
    deduct_packing_from_margin: deduct.packing,
    item_count: totals.item_count,
    total_amount: totals.amount,
    collection_source: o.collection_source,
    cod_collect_amount: (payout.cod_collect_amount as number | null) ?? null,
    courier_name: (courier.name as string | null) ?? null,
    courier_awb_number: (courier.awb_number as string | null) ?? null,
    tracking_url: (courier.tracking_url as string | null) ?? null,
    courier_remittance_ref: (payout.courier_remittance_ref as string | null) ?? null,
    courier_bank_trx_id: (payout.courier_bank_trx_id as string | null) ?? null,
    payout_settlement_status: (payout.settlement_status as string | null) ?? null,
    courier_service_id: (courier.service_id as string | null) ?? null,
    courier_order_ref: (courier.order_ref as string | null) ?? null,
    courier_tracking_number: (courier.tracking_number as string | null) ?? null,
    courier_consignment_id: (courier.consignment_id as string | null) ?? null,
    courier_cost_amount: (courier.cost_amount as number | null) ?? null,
    delivered_at: (courier.delivered_at as string | null) ?? null,
    returned_at: (courier.returned_at as string | null) ?? null,
    sender_name: (pickup.sender_name as string | null) ?? null,
    pickup_phone: (pickup.phone as string | null) ?? null,
    pickup_address: (pickup.address as string | null) ?? null,
    default_sender_name: (pickup.default_sender_name as string | null) ?? null,
    default_pickup_phone: (pickup.default_phone as string | null) ?? null,
    default_pickup_address: (pickup.default_address as string | null) ?? null,
    payout_account_type: (payout.account_type as string | null) ?? null,
    payout_account_info: (payout.account_info as string | null) ?? null,
    default_payout_account_type: (payout.default_account_type as string | null) ?? null,
    default_payout_account_info: (payout.default_account_info as string | null) ?? null,
    package_weight_band: (parcel.weight_band as string | null) ?? null,
    item_category: (parcel.item_category as string | null) ?? null,
    parcel_description: (parcel.description as string | null) ?? null,
    delivery_zone: (parcel.delivery_zone as string | null) ?? null,
    allow_open_box: (parcel.allow_open_box as boolean | null) ?? null,
    driver_notes: (parcel.driver_notes as string | null) ?? null,
    delivery_instruction_notes: (parcel.delivery_instruction_notes as string | null) ?? null,
    return_sub_state: (returnInfo.sub_state as string | null) ?? null,
    return_override_reason: (returnInfo.override_reason as string | null) ?? null,
    return_ref: (returnInfo.ref as string | null) ?? null,
    return_charge_amount: (returnInfo.charge_amount as number | null) ?? null,
    deduct_return_charge_from_middle_man:
      (returnInfo.deduct_charge_from_middle_man as boolean | null) ?? null,
    replacement_of_order_id: (returnInfo.replacement_of_order_id as number | null) ?? null,
    middle_man_reference: (returnInfo.middle_man_reference as string | null) ?? null,
  };

  const items: ShopOrderItem[] = payload.items.map(mapStaffShopOrderDetailItemToFlat);

  return { order: order as ShopOrder, items };
}

function mapStaffShopOrderDetailItemToFlat(item: StaffShopOrderDetailItem): ShopOrderItem {
  const pricing = item.pricing;
  const negotiation = item.negotiation;
  const fulfillment = item.fulfillment;
  const product = item.product;
  const stock = item.stock;

  return {
    id: item.id,
    order_id: item.order_id,
    product_id: product.id,
    global_stock_id: stock?.global_stock_id ?? null,
    global_stock_allocation_id: stock?.global_stock_allocation_id ?? null,
    name: item.name,
    image_url: item.image_url,
    quantity: item.quantity,
    unit_list_price_amount: moneyAmount(pricing.list),
    unit_list_price_currency_id: moneyCurrencyId(pricing.list),
    unit_sell_price_amount: moneyAmount(pricing.sell),
    unit_sell_price_currency_id: moneyCurrencyId(pricing.sell),
    unit_minimum_sell_price_amount: moneyAmount(pricing.minimum_sell),
    unit_minimum_sell_price_currency_id: moneyCurrencyId(pricing.minimum_sell),
    customer_sell_price_amount: null,
    customer_sell_price_currency_id: null,
    customer_offer_amount: offerAmount(negotiation.customer_offer),
    customer_offer_currency_id: offerCurrencyId(negotiation.customer_offer),
    staff_offer_amount: offerAmount(negotiation.staff_offer),
    staff_offer_currency_id: offerCurrencyId(negotiation.staff_offer),
    is_first_offer_manual: negotiation.staff_offer?.is_manual ?? false,
    final_price_amount: offerAmount(negotiation.final_offer),
    final_price_currency_id: offerCurrencyId(negotiation.final_offer),
    is_final_offer_manual: negotiation.final_offer?.is_manual ?? false,
    confirmed_quantity: negotiation.confirmed_quantity,
    weight_kg: negotiation.weight_kg,
    cost_price_amount: moneyAmount(pricing.cost),
    cost_price_currency_id: moneyCurrencyId(pricing.cost),
    customer_decision_status: negotiation.customer_decision,
    customer_decision_at: negotiation.customer_offer?.at ?? null,
    negotiation_status: negotiation.status,
    staff_offer_at: negotiation.staff_offer?.at ?? null,
    customer_counter_at: negotiation.customer_offer?.at ?? null,
    final_offer_at: negotiation.final_offer?.at ?? null,
    returned_quantity: fulfillment.returned,
    procurement_pulled: fulfillment.procurement_pulled,
    sku: product.sku,
    brand: product.brand,
    barcode: product.barcode,
    product_weight_gm: product.weight_gm,
    package_weight_gm: product.package_weight_gm,
    minimum_order_quantity: product.minimum_order_quantity,
    created_at: item.created_at,
    updated_at: item.updated_at,
  };
}

export function parseStaffShopOrderDetailResponse(raw: unknown): StaffShopOrderDetailResponse {
  const payload = raw as StaffShopOrderDetailResponse | null;
  if (!payload?.order) {
    throw new Error('Order not found.');
  }
  return payload;
}
