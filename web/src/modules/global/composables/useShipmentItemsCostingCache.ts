import { globalShipmentRepository } from 'src/modules/procurement_stock/repositories/globalShipmentRepository';
import type { CostingLineItemInput } from 'src/shared/shipment-engine';

/** Line used for live preview fallback + stamp lookup by shipment_item_id. */
export type ShipmentCostingCacheItem = CostingLineItemInput & {
  id: number;
  landed_cost_bdt: number | null;
};

const mapShipmentItem = (item: {
  id: number;
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  ordered_quantity: number;
  landed_cost_bdt?: number | null;
}): ShipmentCostingCacheItem => ({
  id: item.id,
  purchase_price: item.purchase_price,
  product_weight: item.product_weight,
  package_weight: item.package_weight,
  ordered_quantity: item.ordered_quantity,
  landed_cost_bdt:
    item.landed_cost_bdt == null || !Number.isFinite(Number(item.landed_cost_bdt))
      ? null
      : Number(item.landed_cost_bdt),
});

export function createShipmentItemsCostingCache() {
  const cache = new Map<number, ShipmentCostingCacheItem[]>();
  const inflight = new Map<number, Promise<ShipmentCostingCacheItem[]>>();

  const ensureShipmentItems = async (shipmentId: number): Promise<ShipmentCostingCacheItem[]> => {
    if (!shipmentId) return [];

    const cached = cache.get(shipmentId);
    if (cached) return cached;

    const pending = inflight.get(shipmentId);
    if (pending) return pending;

    const promise = globalShipmentRepository
      .listShipmentItems(shipmentId)
      .then((items) => {
        const mapped = items.map((item) =>
          mapShipmentItem({
            id: item.id,
            purchase_price: item.purchase_price,
            product_weight: item.product_weight,
            package_weight: item.package_weight,
            ordered_quantity: item.ordered_quantity,
            landed_cost_bdt: item.landed_cost_bdt ?? null,
          }),
        );
        cache.set(shipmentId, mapped);
        inflight.delete(shipmentId);
        return mapped;
      })
      .catch((error) => {
        inflight.delete(shipmentId);
        throw error;
      });

    inflight.set(shipmentId, promise);
    return promise;
  };

  const getSync = (shipmentId: number): ShipmentCostingCacheItem[] => cache.get(shipmentId) ?? [];

  /** Living stamp for a shipment item, if finalized/revised. */
  const getStampSync = (shipmentId: number, shipmentItemId: number): number | null => {
    const row = getSync(shipmentId).find((i) => i.id === shipmentItemId);
    return row?.landed_cost_bdt ?? null;
  };

  const prefetchShipmentItems = async (shipmentIds: number[]): Promise<void> => {
    const uniqueIds = Array.from(new Set(shipmentIds.filter((id) => id > 0)));
    const toFetchIds = uniqueIds.filter((id) => !cache.has(id) && !inflight.has(id));

    if (toFetchIds.length > 0) {
      const batchPromise = globalShipmentRepository.listShipmentItemsBatch(toFetchIds);

      toFetchIds.forEach((id) => {
        const promise = batchPromise
          .then((groupedItems) => {
            const mapped = (groupedItems[id] || []).map(mapShipmentItem);
            cache.set(id, mapped);
            inflight.delete(id);
            return mapped;
          })
          .catch((error) => {
            inflight.delete(id);
            throw error;
          });
        inflight.set(id, promise);
      });
    }

    await Promise.all(uniqueIds.map((id) => ensureShipmentItems(id)));
  };

  const clear = () => {
    cache.clear();
    inflight.clear();
  };

  const invalidateShipment = (shipmentId: number) => {
    if (!shipmentId) return;
    cache.delete(shipmentId);
    inflight.delete(shipmentId);
  };

  return {
    ensureShipmentItems,
    getSync,
    getStampSync,
    prefetchShipmentItems,
    invalidateShipment,
    clear,
  };
}

let sharedShipmentItemsCostingCache: ReturnType<typeof createShipmentItemsCostingCache> | null = null;

export function getSharedShipmentItemsCostingCache() {
  if (!sharedShipmentItemsCostingCache) {
    sharedShipmentItemsCostingCache = createShipmentItemsCostingCache();
  }
  return sharedShipmentItemsCostingCache;
}

export function invalidateSharedShipmentItemsCostingCache(shipmentId: number) {
  getSharedShipmentItemsCostingCache().invalidateShipment(shipmentId);
}

export type ShipmentItemsCostingCache = ReturnType<typeof createShipmentItemsCostingCache>;
