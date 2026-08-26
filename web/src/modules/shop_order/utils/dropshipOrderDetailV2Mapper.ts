import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { ShopOrder, ShopOrderItem } from '../types';
import type { DropshipInvoiceSummaryState } from './dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoicePickupState,
} from './dropshipInvoiceFulfillment';

export type DropshipOrderDetailV2Permissions = {
  can_show_invoice_paper: boolean;
  can_start_processing: boolean;
  can_mark_ready_for_pickup: boolean;
  can_mark_shipped: boolean;
  can_print_customer_invoice: boolean;
};

export type DropshipOrderDetailV2Response = {
  success: boolean;
  order: ShopOrder & { shipping_post_code?: string | null };
  items: ShopOrderItem[];
  summary: DropshipInvoiceSummaryState;
  computed: {
    items_resell_total: number;
    recipient_charge_total: number;
    recipient_grand_total: number;
    delivery_zone_label: string | null;
  };
  fulfillment: {
    pickup: DropshipInvoicePickupState;
    courier: DropshipInvoiceCourierState;
  };
  lookups: {
    courier_services: CourierServiceRow[];
  };
  permissions: DropshipOrderDetailV2Permissions;
};

const num = (value: unknown, fallback = 0): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const bool = (value: unknown): boolean => value === true;

export function mapDropshipOrderDetailV2Response(raw: unknown): DropshipOrderDetailV2Response {
  const payload = (raw ?? {}) as Record<string, unknown>;
  if (payload.success === false) {
    throw new Error(String(payload.error ?? 'Failed to load dropship order detail'));
  }

  const orderRaw = (payload.order ?? {}) as Record<string, unknown>;
  const summaryRaw = (payload.summary ?? {}) as Record<string, unknown>;
  const computedRaw = (payload.computed ?? {}) as Record<string, unknown>;
  const fulfillmentRaw = (payload.fulfillment ?? {}) as Record<string, unknown>;
  const pickupRaw = (fulfillmentRaw.pickup ?? {}) as Record<string, unknown>;
  const courierRaw = (fulfillmentRaw.courier ?? {}) as Record<string, unknown>;
  const lookupsRaw = (payload.lookups ?? {}) as Record<string, unknown>;
  const permissionsRaw = (payload.permissions ?? {}) as Record<string, unknown>;

  const order: ShopOrder & { shipping_post_code?: string | null } = {
    id: num(orderRaw.id),
    tenant_id: num(orderRaw.tenant_id),
    shop_id: num(orderRaw.shop_id),
    shop_name: (orderRaw.shop_name as string | null) ?? undefined,
    customer_group_id: num(orderRaw.customer_group_id),
    customer_group_name: (orderRaw.customer_group_name as string | null) ?? undefined,
    cart_id: (orderRaw.cart_id as number | null) ?? null,
    order_no: String(orderRaw.order_no ?? ''),
    name: String(orderRaw.name ?? ''),
    shop_type_snapshot: orderRaw.shop_type_snapshot as ShopOrder['shop_type_snapshot'],
    order_mode_snapshot: orderRaw.order_mode_snapshot as ShopOrder['order_mode_snapshot'],
    is_negotiable_snapshot: bool(orderRaw.is_negotiable_snapshot),
    status: orderRaw.status as ShopOrder['status'],
    negotiate_round: num(orderRaw.negotiate_round),
    cargo_rate: null,
    conversion_rate: null,
    profit_rate: null,
    recipient_name: (orderRaw.recipient_name as string | null) ?? null,
    recipient_phone: (orderRaw.recipient_phone as string | null) ?? null,
    recipient_phone_secondary: (orderRaw.recipient_phone_secondary as string | null) ?? null,
    shipping_address: (orderRaw.shipping_address as string | null) ?? null,
    shipping_district: (orderRaw.shipping_district as string | null) ?? null,
    shipping_thana: (orderRaw.shipping_thana as string | null) ?? null,
    shipping_post_code: (orderRaw.shipping_post_code as string | null) ?? null,
    recipient_profile_id: (orderRaw.recipient_profile_id as number | null) ?? null,
    billing_profile_id: (orderRaw.billing_profile_id as number | null) ?? null,
    placed_at: (orderRaw.placed_at as string | null) ?? null,
    fulfilled_at: (orderRaw.fulfilled_at as string | null) ?? null,
    global_invoice_id: (orderRaw.global_invoice_id as number | null) ?? null,
    shop_sell_currency_symbol: (orderRaw.shop_sell_currency_symbol as string | null) ?? null,
    created_by_email: String(orderRaw.created_by_email ?? ''),
    created_at: String(orderRaw.created_at ?? ''),
    updated_at: String(orderRaw.updated_at ?? ''),
    cod_charge_amount: num(orderRaw.cod_charge_amount),
    delivery_charge_amount: num(orderRaw.delivery_charge_amount),
    print_charge_amount: num(orderRaw.print_charge_amount),
    packing_charge_amount: num(orderRaw.packing_charge_amount),
    discount_amount: num(orderRaw.discount_amount),
    is_prepaid_snapshot: bool(orderRaw.is_prepaid_snapshot),
    delivery_instructions: (orderRaw.delivery_instructions as string | null) ?? null,
    deduct_cod_from_margin: bool(orderRaw.deduct_cod_from_margin),
    deduct_delivery_from_margin: bool(orderRaw.deduct_delivery_from_margin),
    deduct_print_from_margin: bool(orderRaw.deduct_print_from_margin),
    deduct_packing_from_margin: bool(orderRaw.deduct_packing_from_margin),
    cod_collect_amount: (orderRaw.cod_collect_amount as number | null) ?? null,
    item_count: num(orderRaw.item_count),
    courier_name: (orderRaw.courier_name as string | null) ?? null,
    courier_awb_number: (orderRaw.courier_awb_number as string | null) ?? null,
    tracking_url: (orderRaw.tracking_url as string | null) ?? null,
  };

  const items: ShopOrderItem[] = ((payload.items as ShopOrderItem[] | null) ?? []).map((item) => ({
    ...item,
    procurement_pulled: item.procurement_pulled ?? false,
    returned_quantity: item.returned_quantity ?? 0,
    confirmed_quantity: item.confirmed_quantity ?? null,
    customer_offer_amount: item.customer_offer_amount ?? null,
    customer_offer_currency_id: item.customer_offer_currency_id ?? null,
    staff_offer_amount: item.staff_offer_amount ?? null,
    staff_offer_currency_id: item.staff_offer_currency_id ?? null,
  }));

  const summary: DropshipInvoiceSummaryState = {
    delivery_charge_amount: num(summaryRaw.delivery_charge_amount),
    deduct_delivery_from_margin: bool(summaryRaw.deduct_delivery_from_margin),
    cod_charge_amount: num(summaryRaw.cod_charge_amount),
    deduct_cod_from_margin: bool(summaryRaw.deduct_cod_from_margin),
    print_charge_amount: num(summaryRaw.print_charge_amount),
    deduct_print_from_margin: bool(summaryRaw.deduct_print_from_margin),
    packing_charge_amount: num(summaryRaw.packing_charge_amount),
    deduct_packing_from_margin: bool(summaryRaw.deduct_packing_from_margin),
    discount_amount: num(summaryRaw.discount_amount),
    cod_collect_amount: num(summaryRaw.cod_collect_amount),
  };

  return {
    success: true,
    order,
    items,
    summary,
    computed: {
      items_resell_total: num(computedRaw.items_resell_total),
      recipient_charge_total: num(computedRaw.recipient_charge_total),
      recipient_grand_total: num(computedRaw.recipient_grand_total),
      delivery_zone_label: (computedRaw.delivery_zone_label as string | null) ?? null,
    },
    fulfillment: {
      pickup: {
        merchant_id: (pickupRaw.merchant_id as string | null) ?? null,
        sender_name: String(pickupRaw.sender_name ?? ''),
        pickup_phone: String(pickupRaw.pickup_phone ?? ''),
        pickup_address: String(pickupRaw.pickup_address ?? ''),
      },
      courier: {
        courier_service_id: (courierRaw.courier_service_id as string | null) ?? null,
        courier_awb_number: String(courierRaw.courier_awb_number ?? ''),
        tracking_url: String(courierRaw.tracking_url ?? ''),
        allow_open_box: bool(courierRaw.allow_open_box),
        cod_charge: num(courierRaw.cod_charge),
      },
    },
    lookups: {
      courier_services: (lookupsRaw.courier_services as CourierServiceRow[] | null) ?? [],
    },
    permissions: {
      can_show_invoice_paper: bool(permissionsRaw.can_show_invoice_paper),
      can_start_processing: bool(permissionsRaw.can_start_processing),
      can_mark_ready_for_pickup: bool(permissionsRaw.can_mark_ready_for_pickup),
      can_mark_shipped: bool(permissionsRaw.can_mark_shipped),
      can_print_customer_invoice: bool(permissionsRaw.can_print_customer_invoice),
    },
  };
}
