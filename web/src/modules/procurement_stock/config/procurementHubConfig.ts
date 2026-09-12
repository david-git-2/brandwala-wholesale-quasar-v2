import type { ModuleKey } from 'src/modules/navigation/modulePermissions';

export const PROCUREMENT_PRIMARY_KEYS = ['demand', 'shipment', 'warehouse'] as const;

export type ProcurementMoreLinkDef = {
  key: string;
  moduleKey: ModuleKey;
  path: string;
  title: string;
  caption: string;
  icon: string;
  weight: number;
};

export const PROCUREMENT_MORE_LINKS: ProcurementMoreLinkDef[] = [
  {
    key: 'child-stock',
    moduleKey: 'inventory',
    path: 'child-stock',
    title: 'Shop Stock',
    caption: 'Stock this shop can sell from received shipments.',
    icon: 'ph ph-package',
    weight: 10,
  },
  {
    key: 'movements',
    moduleKey: 'global_stock_movement',
    path: 'movements',
    title: 'Movements',
    caption: 'Move stock between shelves or sellable / held states.',
    icon: 'ph ph-arrows-left-right',
    weight: 20,
  },
  {
    key: 'locations',
    moduleKey: 'global_stock_location',
    path: 'locations',
    title: 'Locations',
    caption: 'Shelves and boxes where warehouse stock sits.',
    icon: 'ph ph-map-pin',
    weight: 30,
  },
  {
    key: 'progress',
    moduleKey: 'shipment_progress_settings',
    path: 'shipment-progress',
    title: 'Shipment Progress',
    caption: 'Journey stages for shipments and public tracking.',
    icon: 'ph ph-map-trifold',
    weight: 40,
  },
  {
    key: 'cargo',
    moduleKey: 'cargo_company',
    path: 'cargo-companies',
    title: 'Cargo Companies',
    caption: 'Freight agents used on inbound shipments.',
    icon: 'ph ph-airplane-tilt',
    weight: 50,
  },
];

export function filterProcurementMoreLinks(
  links: ProcurementMoreLinkDef[],
  canView: (moduleKey: ModuleKey) => boolean,
): ProcurementMoreLinkDef[] {
  return links
    .filter((link) => canView(link.moduleKey))
    .sort((a, b) => a.weight - b.weight);
}
