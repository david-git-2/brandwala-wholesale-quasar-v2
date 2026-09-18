export type DropshipInvoicePickupState = {
  pickup_location_id: string | null;
  sender_name: string;
  pickup_phone: string;
  pickup_address: string;
};

export type DropshipInvoiceCourierState = {
  courier_service_id: string | null;
  courier_awb_number: string;
  tracking_url: string;
  allow_open_box: boolean;
  cod_charge: number;
};

export type DropshipInvoiceDeliveredQuantitiesState = Record<number, number>;

export function isDropshipLineResolved(item: {
  quantity?: number | null;
  confirmed_quantity?: number | null;
  is_fulfillment_unavailable?: boolean;
  fulfillment_resolved?: boolean;
  stock_picks?: Array<{ quantity?: number | null }> | null;
}): boolean {
  if ((item.quantity ?? 0) <= 0) return true;
  if (item.is_fulfillment_unavailable === true) return true;
  if (item.fulfillment_resolved === true) return true;
  const pickedQty = item.confirmed_quantity ?? 0;
  const stockPickQty = (item.stock_picks ?? []).reduce((sum, pick) => sum + (pick.quantity ?? 0), 0);
  return pickedQty > 0 || stockPickQty > 0;
}

export function createDeliveredQuantitiesFromItems(
  items: Array<{
    id: number;
    quantity: number;
    confirmed_quantity?: number | null;
    is_fulfillment_unavailable?: boolean;
  }>,
): DropshipInvoiceDeliveredQuantitiesState {
  return Object.fromEntries(
    items.map((item) => [
      item.id,
      item.is_fulfillment_unavailable ? 0 : (item.confirmed_quantity ?? 0),
    ]),
  );
}
