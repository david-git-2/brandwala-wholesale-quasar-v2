export type PpPurchaseRequestStatus = 'draft' | 'requested';

export type PpOrderLineStatus = 'draft' | 'requested' | 'processing' | 'done' | 'cancelled';

/** Stored as `placement_status`; staff UI labels this Fulfillment. */
export type PpOrderLinePlacementStatus =
  | 'none'
  | 'draft'
  | 'requested'
  | 'processing'
  | 'cancelled'
  | 'added_to_cart'
  | 'order_placed'
  | 'cargo_warehouse'
  | 'in_flight'
  | 'local_warehouse'
  | 'delivered'
  | 'lost';

export interface PpPurchaseRequestListItem {
  id: number;
  request_number: string | null;
  status: PpPurchaseRequestStatus;
  created_at: string;
  updated_at: string;
  line_count: number;
}

export interface PpPurchaseRequestStaffListItem extends PpPurchaseRequestListItem {
  people_group_id: number;
  people_group_name: string;
}

export interface PpPurchaseRequest {
  id: number;
  tenant_id: number;
  people_group_id: number;
  created_by_member_id: number;
  status: PpPurchaseRequestStatus;
  request_number: string | null;
  bucket_description: string | null;
  created_at: string;
  updated_at: string;
}

export interface PpOrderLine {
  id: number;
  purchase_request_id: number;
  pp_customer_group_id: number;
  url: string;
  tracking_url: string | null;
  needed_qty: number;
  description: string | null;
  product_name: string | null;
  image_url: string | null;
  unit_price: number | null;
  pp_supplier_group_id: number | null;
  shipment_id: number | null;
  shipment_status?: string | null;
  is_added_to_cart: boolean;
  added_to_cart_at: string | null;
  placement_status: PpOrderLinePlacementStatus;
  placed_qty: number | null;
  received_qty: number | null;
  status: PpOrderLineStatus;
  created_at: string;
  customer_group_name?: string | null;
  supplier_group_name?: string | null;
  request_number?: string | null;
  request_bucket_description?: string | null;
}

export type PpStaffOrderLineUpdatePayload = {
  lineId: number;
  url: string;
  tracking_url?: string | null;
  needed_qty: number;
  description?: string | null;
  product_name?: string | null;
  image_url?: string | null;
  unit_price?: number | null;
  pp_supplier_group_id?: number | null;
  shipment_id?: number | null;
  is_added_to_cart: boolean;
  placement_status: PpOrderLinePlacementStatus;
  placed_qty?: number | null;
  received_qty?: number | null;
  status: PpOrderLineStatus;
};