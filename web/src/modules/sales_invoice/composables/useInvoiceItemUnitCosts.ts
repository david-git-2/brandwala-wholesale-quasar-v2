import { ref } from 'vue';
import type { GlobalInvoiceItemRow } from '../types';
import { createShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import { resolveGlobalStockUnitCostSync } from 'src/modules/global/utils/resolveGlobalStockUnitCost';

export function useInvoiceItemUnitCosts() {
  const itemCostingCache = createShipmentItemsCostingCache();
  const resolvedItemUnitCosts = ref(new Map<number, number>());

  const resolveItemUnitCosts = async (rows: GlobalInvoiceItemRow[]) => {
    const shipmentIds = rows
      .map((row) => row.costing?.shipment_id)
      .filter((id): id is number => typeof id === 'number' && id > 0);
    await itemCostingCache.prefetchShipmentItems(shipmentIds);

    const next = new Map<number, number>();
    for (const row of rows) {
      if (!row.costing) continue;
      next.set(
        row.id,
        resolveGlobalStockUnitCostSync(
          row.costing,
          itemCostingCache.getSync(row.costing.shipment_id),
        ),
      );
    }
    resolvedItemUnitCosts.value = next;
  };

  const getItemUnitCost = (row: GlobalInvoiceItemRow): number | null =>
    resolvedItemUnitCosts.value.get(row.id) ?? null;

  return {
    itemCostingCache,
    resolvedItemUnitCosts,
    resolveItemUnitCosts,
    getItemUnitCost,
  };
}
