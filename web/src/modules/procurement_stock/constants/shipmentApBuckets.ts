import type { Database } from 'src/types/database.types';

export type ShipmentCostBucket = Database['public']['Enums']['global_shipment_cost_bucket'];

/** Active AP `ap_kind` values synced from shipment cost buckets. */
export const SHIPMENT_AP_COST_BUCKETS: ShipmentCostBucket[] = [
  'material',
  'freight',
  'customs',
  'handling',
  'finance',
  'other',
];

/** Legacy rollup kinds (pre-bucket); may still exist on old paid bills. */
export const LEGACY_SHIPMENT_AP_KINDS = ['vendor', 'cargo', 'local'] as const;

export type ShipmentApKind = ShipmentCostBucket | (typeof LEGACY_SHIPMENT_AP_KINDS)[number];

export function shipmentApKindLabel(kind: string | null | undefined): string {
  if (!kind) return 'AP bill';
  const labels: Record<string, string> = {
    vendor: 'Vendor AP',
    cargo: 'Cargo AP',
    local: 'Local AP',
    material: 'Material AP',
    freight: 'Freight AP',
    customs: 'Customs AP',
    handling: 'Handling AP',
    finance: 'Finance AP',
    other: 'Other AP',
  };
  return labels[kind] ?? `${kind} AP`;
}
