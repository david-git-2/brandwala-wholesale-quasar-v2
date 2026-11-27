import type {
  PpOrderLine,
  PpStaffOrderLineUpdatePayload,
  PpStaffOrderLineWritePayload,
} from '../types/ppPurchaseRequest';
import {
  derivePpLineStatusFromPlacement,
  ppPlacementImpliesAddedToCart,
} from './ppOrderLinePlacement';

export type PpStaffOrderLineFormInput = {
  url: string;
  tracking_url?: string | null;
  needed_qty: number;
  description?: string | null;
  product_name?: string | null;
  image_url?: string | null;
  unit_price?: number | null;
  pp_supplier_group_id?: number | null;
  shipment_id?: number | null;
  placement_status: PpOrderLine['placement_status'];
  placed_qty?: number | null;
  received_qty?: number | null;
};

export function buildPpStaffOrderLineWrite(
  form: PpStaffOrderLineFormInput,
): PpStaffOrderLineWritePayload {
  const placement_status =
    form.placement_status === 'none' ? 'requested' : form.placement_status;
  return {
    url: form.url.trim(),
    tracking_url: form.tracking_url?.trim() || null,
    needed_qty: form.needed_qty,
    description: form.description?.trim() || null,
    product_name: form.product_name?.trim() || null,
    image_url: form.image_url?.trim() || null,
    unit_price: form.unit_price,
    pp_supplier_group_id: form.pp_supplier_group_id ?? null,
    shipment_id: form.shipment_id ?? null,
    placement_status,
    placed_qty: form.placed_qty ?? null,
    received_qty: form.received_qty ?? null,
    is_added_to_cart: ppPlacementImpliesAddedToCart(placement_status),
    status: derivePpLineStatusFromPlacement(placement_status),
  };
}

export function buildPpStaffOrderLineUpdate(
  line: PpOrderLine,
  patch: Partial<Omit<PpStaffOrderLineUpdatePayload, 'lineId'>> = {},
): PpStaffOrderLineUpdatePayload {
  const placement_status = patch.placement_status ?? line.placement_status;
  return {
    lineId: line.id,
    url: patch.url ?? line.url,
    tracking_url: patch.tracking_url !== undefined ? patch.tracking_url : line.tracking_url,
    needed_qty: patch.needed_qty ?? line.needed_qty,
    description: patch.description !== undefined ? patch.description : line.description,
    product_name: patch.product_name !== undefined ? patch.product_name : line.product_name,
    image_url: patch.image_url !== undefined ? patch.image_url : line.image_url,
    unit_price: patch.unit_price !== undefined ? patch.unit_price : line.unit_price,
    pp_supplier_group_id:
      patch.pp_supplier_group_id !== undefined
        ? patch.pp_supplier_group_id
        : line.pp_supplier_group_id,
    shipment_id: patch.shipment_id !== undefined ? patch.shipment_id : line.shipment_id,
    placed_qty: patch.placed_qty !== undefined ? patch.placed_qty : line.placed_qty,
    received_qty: patch.received_qty !== undefined ? patch.received_qty : line.received_qty,
    placement_status,
    is_added_to_cart: ppPlacementImpliesAddedToCart(placement_status),
    status: derivePpLineStatusFromPlacement(placement_status),
  };
}