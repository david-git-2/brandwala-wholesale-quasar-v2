import type { PpOrderLinePlacementStatus } from './ppPurchaseRequest';

export type PpAppOrderLineGroupBy = 'none' | 'store_url';

export type PpAppOrderLineListFilters = {
  pp_customer_group_id: number | null;
  pp_supplier_group_id: number | null;
  shipment_id: number | null;
  placement_statuses: PpOrderLinePlacementStatus[];
  url_hosts: string[];
};

export const emptyPpAppOrderLineListFilters = (): PpAppOrderLineListFilters => ({
  pp_customer_group_id: null,
  pp_supplier_group_id: null,
  shipment_id: null,
  placement_statuses: [],
  url_hosts: [],
});

export type PpAppOrderLineFilterGroupOption = {
  id: number;
  name: string;
};

export type PpAppOrderLineFilterShipmentOption = {
  id: number;
  name: string;
  shipment_code: string;
};

export type PpAppOrderLineStaffFilterOptions = {
  url_hosts: string[];
  placement_statuses: PpOrderLinePlacementStatus[];
  customer_groups: PpAppOrderLineFilterGroupOption[];
  supplier_groups: PpAppOrderLineFilterGroupOption[];
  shipments: PpAppOrderLineFilterShipmentOption[];
};

export function countActivePpAppOrderLineFilters(filters: PpAppOrderLineListFilters): number {
  let count = 0;
  if (filters.pp_customer_group_id != null) count += 1;
  if (filters.pp_supplier_group_id != null) count += 1;
  if (filters.shipment_id != null) count += 1;
  if (filters.placement_statuses.length > 0) count += 1;
  if (filters.url_hosts.length > 0) count += 1;
  return count;
}

export function serializePpAppOrderLineListFilters(
  filters: PpAppOrderLineListFilters,
): string {
  return JSON.stringify({
    c: filters.pp_customer_group_id,
    s: filters.pp_supplier_group_id,
    sh: filters.shipment_id,
    p: [...filters.placement_statuses].sort(),
    u: filters.url_hosts.map((h) => h.trim().toLowerCase()).filter(Boolean).sort(),
  });
}

export function normalizePpAppOrderLineUrlHosts(hosts: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of hosts) {
    const host = raw.trim().toLowerCase();
    if (!host || seen.has(host)) continue;
    seen.add(host);
    out.push(host);
  }
  return out;
}