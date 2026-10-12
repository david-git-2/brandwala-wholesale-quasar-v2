import type {
  GlobalShipmentCostBucket,
  GlobalShipmentCostComponent,
} from '../types/shipmentCostEntry';

export const SHIPMENT_COST_BUCKET_SELECT_OPTIONS: Array<{
  label: string;
  value: GlobalShipmentCostBucket;
}> = [
  { label: 'Material', value: 'material' },
  { label: 'Freight', value: 'freight' },
  { label: 'Customs', value: 'customs' },
  { label: 'Handling', value: 'handling' },
  { label: 'Finance', value: 'finance' },
  { label: 'Other', value: 'other' },
];

export const SHIPMENT_COST_COMPONENT_SELECT_OPTIONS: Array<{
  label: string;
  value: GlobalShipmentCostComponent;
}> = [
  { label: 'Subtotal', value: 'subtotal' },
  { label: 'Carriage', value: 'carriage' },
  { label: 'VAT / tax', value: 'vat_tax' },
  { label: 'Misc', value: 'misc' },
];
