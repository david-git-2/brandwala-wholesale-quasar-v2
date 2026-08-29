import type { Vendor } from 'src/modules/vendor/types';

export interface ShipmentSectionMetadata {
  invoice_number?: string | undefined;
  invoice_date?: string | undefined;
  notes?: string | undefined;
  carton_ids?: string[] | undefined;
  [key: string]: unknown;
}

export interface ShipmentSection {
  id: number;
  parent_tenant_id: number;
  shipment_id: number;
  vendor_id: number;
  vendor?: Vendor | null;
  title: string;
  sort_order: number;
  metadata: ShipmentSectionMetadata;
  items_count?: number;
  total_weight_kg?: number;
  created_at: string;
  updated_at: string;
}

export interface CreateShipmentSectionPayload {
  parent_tenant_id?: number;
  shipment_id: number;
  vendor_id?: number;
  title: string;
  sort_order?: number;
  metadata?: ShipmentSectionMetadata;
}

export interface UpdateShipmentSectionPayload {
  vendor_id?: number;
  title?: string;
  sort_order?: number;
  metadata?: ShipmentSectionMetadata;
}
