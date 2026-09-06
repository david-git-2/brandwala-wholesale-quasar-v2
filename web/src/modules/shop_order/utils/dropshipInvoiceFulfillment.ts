export type DropshipInvoicePickupState = {
  merchant_id: string | null;
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
