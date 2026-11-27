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

export type PpShipmentSelectOption = {
  value: number | null;
  label: string;
  name: string;
  shipmentCode: string;
};

export const PP_SHIPMENT_NONE_SELECT_OPTION: PpShipmentSelectOption = {
  value: null,
  label: 'None',
  name: 'None',
  shipmentCode: '',
};

export function toPpShipmentSelectOption(shipment: PpShipment): PpShipmentSelectOption {
  const name = shipment.name?.trim() ?? '';
  const shipmentCode = shipment.shipment_code?.trim() ?? '';
  return {
    value: shipment.id,
    label: name || shipmentCode || `#${shipment.id}`,
    name: name || shipmentCode || `#${shipment.id}`,
    shipmentCode,
  };
}

export function buildPpShipmentSelectOptions(shipments: PpShipment[]): PpShipmentSelectOption[] {
  return [
    PP_SHIPMENT_NONE_SELECT_OPTION,
    ...shipments.map(toPpShipmentSelectOption),
  ];
}