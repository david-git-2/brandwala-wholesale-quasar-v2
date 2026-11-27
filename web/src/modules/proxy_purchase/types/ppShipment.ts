export type PpShipmentStatus = 'draft' | 'in_transit' | 'received' | 'cancelled';

export type PpShipment = {
  id: number;
  tenant_id: number;
  name: string;
  shipment_code: string;
  status: PpShipmentStatus;
  created_at: string;
};

export const PP_SHIPMENT_STATUS_LABELS: Record<PpShipmentStatus, string> = {
  draft: 'Draft',
  in_transit: 'In transit',
  received: 'Received',
  cancelled: 'Cancelled',
};