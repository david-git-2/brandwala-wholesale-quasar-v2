import { globalShipmentRepository } from 'src/modules/procurement_stock/repositories/globalShipmentRepository';
import type { CostingLineItemInput } from 'src/modules/procurement_stock/utils/landedCost';

const mapShipmentItem = (item: {
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  ordered_quantity: number;
}): CostingLineItemInput => ({
  purchase_price: item.purchase_price,
  product_weight: item.product_weight,
  package_weight: item.package_weight,
  ordered_quantity: item.ordered_quantity,
});

export function createShipmentItemsCostingCache() {
  const cache = new Map<number, CostingLineItemInput[]>();
  const inflight = new Map<number, Promise<CostingLineItemInput[]>>();

  const ensureShipmentItems = async (shipmentId: number): Promise<CostingLineItemInput[]> => {
    if (!shipmentId) return [];

    const cached = cache.get(shipmentId);
    if (cached) return cached;

    const pending = inflight.get(shipmentId);
    if (pending) return pending;

    const promise = globalShipmentRepository
      .listShipmentItems(shipmentId)
      .then((items) => {
        const mapped = items.map(mapShipmentItem);
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

  const getSync = (shipmentId: number): CostingLineItemInput[] => cache.get(shipmentId) ?? [];

  const prefetchShipmentItems = async (shipmentIds: number[]): Promise<void> => {
    const uniqueIds = Array.from(new Set(shipmentIds.filter((id) => id > 0)));
    const toFetchIds = uniqueIds.filter((id) => !cache.has(id) && !inflight.has(id));

    if (toFetchIds.length > 0) {
      const batchPromise = globalShipmentRepository.listShipmentItemsBatch(toFetchIds);

      toFetchIds.forEach((id) => {
        const promise = batchPromise
          .then((groupedItems) => {
            const mapped = groupedItems[id] || [];
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

  return {
    ensureShipmentItems,
    getSync,
    prefetchShipmentItems,
    clear,
  };
}

export type ShipmentItemsCostingCache = ReturnType<typeof createShipmentItemsCostingCache>;
