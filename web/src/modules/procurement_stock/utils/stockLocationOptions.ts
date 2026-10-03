import {
  STOCK_LOCATION_KIND_LABELS,
  isRootStockLocationKind,
} from '../constants/stockLocationHierarchy';
import type { StockLocation, StockLocationKind } from '../types/stockLocation';

export type StockLocationChain = Partial<Record<StockLocationKind, StockLocation>>;

/** Walk parents from a node up to roots. */
export function getStockLocationChain(
  locations: StockLocation[],
  locationId: number | null | undefined,
): StockLocationChain {
  if (locationId == null) return {};
  const byId = new Map(locations.map((loc) => [loc.id, loc]));
  const chain: StockLocationChain = {};
  let cur = byId.get(locationId);
  const seen = new Set<number>();
  while (cur && !seen.has(cur.id)) {
    seen.add(cur.id);
    chain[cur.kind] = cur;
    cur =
      cur.parent_location_id != null ? byId.get(cur.parent_location_id) : undefined;
  }
  return chain;
}

export function formatLocationOption(loc: StockLocation): string {
  return `${loc.code} — ${loc.name}`;
}

export function activeChildrenOfKind(
  locations: StockLocation[],
  parentId: number | null,
  kind: StockLocationKind,
): StockLocation[] {
  return locations
    .filter(
      (loc) =>
        loc.is_active &&
        loc.kind === kind &&
        loc.parent_location_id === parentId,
    )
    .sort((a, b) => a.sort_order - b.sort_order || a.code.localeCompare(b.code));
}

export function activeRootSites(locations: StockLocation[]): StockLocation[] {
  return locations
    .filter(
      (loc) =>
        loc.is_active &&
        loc.parent_location_id == null &&
        isRootStockLocationKind(loc.kind),
    )
    .sort((a, b) => a.sort_order - b.sort_order || a.code.localeCompare(b.code));
}

/**
 * Returns leaf stock locations (active locations with no active children).
 */
export function getLeafLocations(locations: StockLocation[]): StockLocation[] {
  const activeChildrenParentIds = new Set(
    locations
      .filter((loc) => loc.is_active && loc.parent_location_id != null)
      .map((loc) => loc.parent_location_id as number),
  );

  return locations.filter(
    (loc) => loc.is_active && !activeChildrenParentIds.has(loc.id),
  );
}

/**
 * Resolves the default put-away location ID from active leaf locations.
 * Rule: is_default first, fallback first active pickable leaf.
 */
export function getDefaultPutawayLocationId(locations: StockLocation[]): number | null {
  const leaves = getLeafLocations(locations);
  if (leaves.length === 0) return null;

  const sorted = [...leaves].sort((a, b) => {
    if (a.is_default !== b.is_default) return a.is_default ? -1 : 1;
    if (a.is_pickable !== b.is_pickable) return a.is_pickable ? -1 : 1;
    if (a.sort_order !== b.sort_order) return a.sort_order - b.sort_order;
    return a.id - b.id;
  });

  return sorted[0]?.id ?? null;
}

/**
 * Formats a list of locations as select options for Quasar q-select.
 */
export function toLocationSelectOptions(locations: StockLocation[]): { label: string; value: number }[] {
  return locations.map((loc) => ({
    label: `${loc.code} — ${loc.name}`,
    value: loc.id,
  }));
}

export function toLocationSelectOptionsWithPath(
  allLocations: StockLocation[],
  locations: StockLocation[],
): { label: string; value: number }[] {
  return locations.map((loc) => {
    const path = formatStockLocationPath(allLocations, loc.id);
    const short = path.length > 56 ? `${path.slice(0, 53)}…` : path;
    return {
      label: `${loc.code} — ${loc.name} (${short})`,
      value: loc.id,
    };
  });
}

/** Location id plus all descendants (for invalid parent picks on edit). */
export function collectDescendantLocationIds(
  locations: StockLocation[],
  rootId: number,
): Set<number> {
  const childrenByParent = new Map<number, number[]>();
  for (const loc of locations) {
    const parentId = loc.parent_location_id;
    if (parentId == null) continue;
    const list = childrenByParent.get(parentId) ?? [];
    list.push(loc.id);
    childrenByParent.set(parentId, list);
  }

  const blocked = new Set<number>([rootId]);
  const stack = [rootId];
  while (stack.length > 0) {
    const id = stack.pop()!;
    for (const childId of childrenByParent.get(id) ?? []) {
      if (!blocked.has(childId)) {
        blocked.add(childId);
        stack.push(childId);
      }
    }
  }
  return blocked;
}

/** Breadcrumb from warehouse root to this node (e.g. MAIN › A1 › BIN-3). */
export function formatStockLocationPath(
  locations: StockLocation[],
  locationId: number | null | undefined,
): string {
  if (locationId == null) return '—';
  const byId = new Map(locations.map((loc) => [loc.id, loc]));
  const parts: string[] = [];
  let cur = byId.get(locationId);
  const seen = new Set<number>();
  while (cur && !seen.has(cur.id)) {
    seen.add(cur.id);
    const kindLabel = STOCK_LOCATION_KIND_LABELS[cur.kind];
    parts.unshift(`${kindLabel}: ${cur.code}`);
    cur =
      cur.parent_location_id != null ? byId.get(cur.parent_location_id) : undefined;
  }
  return parts.length ? parts.join(' › ') : '—';
}
