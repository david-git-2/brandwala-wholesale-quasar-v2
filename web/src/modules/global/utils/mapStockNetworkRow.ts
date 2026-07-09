import type { InventoryItemWithStock, Shipment } from '../types';

import type { GlobalStockRow, StockNetworkRow } from '../types';
import { mapGlobalStockToInventoryView } from './mapGlobalStockToInventoryView';

export const mapStockNetworkToGlobalStockRow = (row: StockNetworkRow): GlobalStockRow => ({
  id: row.global_stock_id,
  tenant_id: row.holding_tenant_id,
  parent_tenant_id: row.parent_tenant_id,
  name: row.name,
  shipment_id: row.shipment_id,
  shipment_item_id: row.shipment_item_id,
  ordered_quantity: row.ordered_quantity,
  purchase_price: row.purchase_price,
  product_weight: row.product_weight,
  package_weight: row.package_weight,
  shipment_type: row.shipment_type,
  product_conversion_rate: row.product_conversion_rate,
  cargo_conversion_rate: row.cargo_conversion_rate,
  cargo_rate: row.cargo_rate,
  received_weight: row.received_weight,
  transaction_rate: row.transaction_rate,
  product_id: row.product_id,
  barcode: row.barcode,
  product_code: row.product_code,
  image_url: row.image_url,
  excellent_qty: row.excellent_qty,
  box_less_qty: row.box_less_qty,
  box_damage_qty: row.box_damage_qty,
  expired_qty: row.expired_qty,
  stolen_qty: row.stolen_qty,
  reserved_qty: row.reserved_qty,
  total_qty: row.total_qty,
});

export const mapStockNetworkToInventoryView = (
  row: StockNetworkRow,
  shipment?: Shipment | null,
  unitCost?: number,
): InventoryItemWithStock =>
  mapGlobalStockToInventoryView(mapStockNetworkToGlobalStockRow(row), shipment, unitCost);

export type StockNetworkProductGroup = {
  key: string;
  product_id: number | null;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  resolvedUnitCost?: number;
  global_stock_id: number;
  shipment_id: number;
  contexts: StockNetworkRow[];
};

export const groupStockNetworkRows = (rows: StockNetworkRow[]): StockNetworkProductGroup[] => {
  const groups = new Map<string, StockNetworkProductGroup>();

  for (const row of rows) {
    const key = row.product_group_key;
    let group = groups.get(key);
    if (!group) {
      group = {
        key,
        product_id: row.product_id,
        name: row.name,
        image_url: row.image_url,
        barcode: row.barcode,
        product_code: row.product_code,
        global_stock_id: row.global_stock_id,
        shipment_id: row.shipment_id,
        contexts: [],
        ...(row.resolvedUnitCost != null ? { resolvedUnitCost: row.resolvedUnitCost } : {}),
      };
      groups.set(key, group);
    }
    group!.contexts.push(row);
    if (row.resolvedUnitCost != null) {
      group.resolvedUnitCost = row.resolvedUnitCost;
    }
  }

  return Array.from(groups.values());
};

export const pickableContext = (group: StockNetworkProductGroup) =>
  group.contexts.find((ctx) => ctx.is_pickable) ?? group.contexts[0] ?? null;
