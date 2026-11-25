import type { Json } from 'src/types/database.types';
import type { OrderItemPickStockRow } from '../repositories/shopOrderRepository';
import type { ShopOrderItem } from '../types';

export type CatalogBillLineSourceRow = {
  global_stock_id: number | null;
  name_snapshot: string | null;
  quantity: number;
  sell_price_amount: number;
  line_total_amount: number;
  shipment_item_id: number | null;
  product_id: number | null;
  line_meta: Record<string, unknown> | null;
};

export function resolveCatalogOrderItemSellPrice(item: ShopOrderItem): number {
  return Number(
    item.final_price_amount ?? item.staff_offer_amount ?? item.unit_sell_price_amount ?? 0,
  );
}

export function catalogBillLineRowToKernelLine(row: CatalogBillLineSourceRow): Record<string, unknown> {
  const qty = Number(row.quantity);
  const unit = Number(row.sell_price_amount);
  const lineTotal = Number(row.line_total_amount ?? qty * unit);
  const meta = { ...(row.line_meta ?? {}), currency_code: 'BDT' };
  return {
    item_kind: 'stock',
    description: row.name_snapshot?.trim() || 'Line',
    quantity: qty,
    unit_price: unit,
    line_total: lineTotal,
    product_id: row.product_id ?? undefined,
    global_stock_id: row.global_stock_id ?? undefined,
    shipment_item_id: row.shipment_item_id ?? undefined,
    meta,
  };
}

export function buildCatalogBillKernelLineFromPick(input: {
  orderItem: ShopOrderItem;
  stockRow: OrderItemPickStockRow;
  quantity: number;
  pickId: number;
  billStockId?: number | null;
}): Record<string, unknown> {
  const sell = resolveCatalogOrderItemSellPrice(input.orderItem);
  const qty = input.quantity;
  const stockId = input.billStockId ?? input.stockRow.global_stock_id;
  return {
    item_kind: 'stock',
    description: input.stockRow.item_name || input.orderItem.name,
    quantity: qty,
    unit_price: sell,
    line_total: sell * qty,
    product_id: input.orderItem.product_id ?? undefined,
    global_stock_id: stockId,
    shipment_item_id: input.stockRow.shipment_item_id,
    meta: {
      currency_code: 'BDT',
      barcode: input.stockRow.barcode,
      product_code: input.stockRow.product_code,
      shop_order_item_id: input.orderItem.id,
      shop_order_item_stock_pick_id: input.pickId,
      source_global_stock_id: input.stockRow.global_stock_id,
    },
  };
}

const kernelLineSourceStockId = (line: Record<string, unknown>): number => {
  const meta = (line.meta ?? {}) as Record<string, unknown>;
  const source = Number(meta.source_global_stock_id ?? 0);
  return source > 0 ? source : Number(line.global_stock_id ?? 0);
};

export function mergeCatalogPickIntoKernelLines(
  existing: Record<string, unknown>[],
  orderItemId: number,
  sourceStockId: number,
  newLine: Record<string, unknown>,
): Record<string, unknown>[] {
  const lineOrderItemId = (line: Record<string, unknown>) => {
    const meta = (line.meta ?? {}) as Record<string, unknown>;
    return Number(meta.shop_order_item_id ?? 0);
  };

  const idx = existing.findIndex(
    (line) =>
      lineOrderItemId(line) === orderItemId && kernelLineSourceStockId(line) === sourceStockId,
  );
  if (idx < 0) {
    return [...existing, newLine];
  }

  const prev = existing[idx]!;
  const prevQty = Number(prev.quantity ?? 0);
  const addQty = Number(newLine.quantity ?? 0);
  const unit = Number(newLine.unit_price ?? prev.unit_price ?? 0);
  const nextQty = prevQty + addQty;
  const merged = {
    ...prev,
    quantity: nextQty,
    unit_price: unit,
    line_total: unit * nextQty,
    meta: newLine.meta ?? prev.meta,
  };
  return existing.map((line, i) => (i === idx ? merged : line));
}

const kernelLineMatchesProductStock = (
  line: Record<string, unknown>,
  productId: number,
  sourceStockId: number,
): boolean => {
  const pid = Number(productId ?? 0);
  const sid = Number(sourceStockId ?? 0);
  if (sid <= 0) return false;
  const linePid = Number(line.product_id ?? 0);
  if (pid > 0 && linePid !== pid) return false;
  if (kernelLineSourceStockId(line) === sid) return true;
  const lineStockId = Number(line.global_stock_id ?? 0);
  return lineStockId > 0 && lineStockId === sid;
};

/** Set absolute qty on the matching catalog stock line (product + sellable stock). */
export function setCatalogKernelLineQtyAbsoluteByProductStock(
  lines: Record<string, unknown>[],
  productId: number,
  sourceStockId: number,
  targetQty: number,
  metaPatch?: Record<string, unknown>,
): Record<string, unknown>[] {
  return lines.map((line) => {
    if (!kernelLineMatchesProductStock(line, productId, sourceStockId)) return line;
    const meta = (line.meta ?? {}) as Record<string, unknown>;
    const unit = Number(line.unit_price ?? 0);
    const nextMeta = metaPatch ? { ...meta, ...metaPatch } : meta;
    return {
      ...line,
      quantity: targetQty,
      unit_price: unit,
      line_total: unit * targetQty,
      meta: nextMeta,
    };
  });
}

/** Set absolute qty on the matching catalog stock line (same order item + sellable stock). */
export function setCatalogKernelLineQtyAbsolute(
  lines: Record<string, unknown>[],
  orderItemId: number,
  sourceStockId: number,
  targetQty: number,
  metaPatch?: Record<string, unknown>,
): Record<string, unknown>[] {
  return lines.map((line) => {
    const meta = (line.meta ?? {}) as Record<string, unknown>;
    if (Number(meta.shop_order_item_id ?? 0) !== orderItemId) return line;
    if (kernelLineSourceStockId(line) !== sourceStockId) return line;
    const unit = Number(line.unit_price ?? 0);
    const nextMeta = metaPatch ? { ...meta, ...metaPatch } : meta;
    return {
      ...line,
      quantity: targetQty,
      unit_price: unit,
      line_total: unit * targetQty,
      meta: nextMeta,
    };
  });
}

export function kernelLinesWithoutStockPick(
  lines: Record<string, unknown>[],
  pickId: number,
): Record<string, unknown>[] {
  return lines.filter((line) => {
    const meta = (line.meta ?? {}) as Record<string, unknown>;
    return Number(meta.shop_order_item_stock_pick_id ?? 0) !== pickId;
  });
}

export function removeCatalogKernelLineForProductStock(
  lines: Record<string, unknown>[],
  productId: number,
  sourceStockId: number,
): Record<string, unknown>[] {
  return lines.filter((line) => !kernelLineMatchesProductStock(line, productId, sourceStockId));
}

export function kernelLinesToJson(lines: Record<string, unknown>[]): Json {
  return lines as Json;
}

export function qtyOnBillForOrderItem(
  lines: CatalogBillLineSourceRow[],
  orderItemId: number,
): number {
  return lines.reduce((sum, row) => {
    const meta = row.line_meta ?? {};
    const oi = Number(meta.shop_order_item_id ?? 0);
    if (oi !== orderItemId) return sum;
    return sum + Number(row.quantity ?? 0);
  }, 0);
}

/** Sellable lot key for a catalog bill stock line (`source_global_stock_id` when present). */
export function catalogBillLineSourceStockId(line: CatalogBillLineSourceRow): number {
  const meta = line.line_meta ?? {};
  const source = Number(meta.source_global_stock_id ?? 0);
  return source > 0 ? source : Number(line.global_stock_id ?? 0);
}

export function catalogBillLineMatchesProductStock(
  row: CatalogBillLineSourceRow,
  productId: number,
  sourceGlobalStockId: number,
): boolean {
  const pid = Number(productId ?? 0);
  const sid = Number(sourceGlobalStockId ?? 0);
  if (sid <= 0) return false;
  const linePid = Number(row.product_id ?? 0);
  if (pid > 0 && linePid !== pid) return false;
  if (catalogBillLineSourceStockId(row) === sid) return true;
  const lineStockId = Number(row.global_stock_id ?? 0);
  return lineStockId > 0 && lineStockId === sid;
}

/** Match draft bill line by product + sellable stock lot. */
export function findCatalogBillLineForProductStock(
  lines: CatalogBillLineSourceRow[],
  productId: number,
  sourceGlobalStockId: number,
): CatalogBillLineSourceRow | undefined {
  return lines.find((row) =>
    catalogBillLineMatchesProductStock(row, productId, sourceGlobalStockId),
  );
}

/** Match draft bill line to sellable lot id from the pick list (`source_global_stock_id`). */
export function findCatalogBillLineForSourceStock(
  lines: CatalogBillLineSourceRow[],
  orderItemId: number,
  sourceGlobalStockId: number,
): CatalogBillLineSourceRow | undefined {
  return lines.find((row) => {
    const meta = row.line_meta ?? {};
    if (Number(meta.shop_order_item_id ?? 0) !== orderItemId) return false;
    if (catalogBillLineSourceStockId(row) === sourceGlobalStockId) return true;
    const lineStockId = Number(row.global_stock_id ?? 0);
    return lineStockId > 0 && lineStockId === sourceGlobalStockId;
  });
}

export function billQtyForSourceStock(
  lines: CatalogBillLineSourceRow[],
  orderItemId: number,
  sourceGlobalStockId: number,
): number {
  const row = findCatalogBillLineForSourceStock(lines, orderItemId, sourceGlobalStockId);
  return row ? Number(row.quantity ?? 0) : 0;
}