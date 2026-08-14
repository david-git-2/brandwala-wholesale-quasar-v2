import type { StockLocation } from '../types/stockLocation';

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
