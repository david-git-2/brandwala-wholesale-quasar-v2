import type { DropshipOrderDetailV2Response } from './dropshipOrderDetailV2Mapper';
import { isDropshipLineResolved } from './dropshipInvoiceFulfillment';

export type StockPickOrderLinePatch = {
  id: number;
  confirmed_quantity?: number | null;
  fulfillment_resolved?: boolean;
};

export function applyStockPickOrderLineToDetail(
  detail: DropshipOrderDetailV2Response,
  orderLine: StockPickOrderLinePatch,
  codCollectAmount?: number | null,
): DropshipOrderDetailV2Response {
  const items = detail.items.map((item) =>
    item.id === orderLine.id
      ? {
          ...item,
          confirmed_quantity:
            orderLine.confirmed_quantity !== undefined
              ? orderLine.confirmed_quantity
              : item.confirmed_quantity,
          fulfillment_resolved:
            orderLine.fulfillment_resolved !== undefined
              ? orderLine.fulfillment_resolved
              : item.fulfillment_resolved,
        }
      : item,
  );

  const activeLines = items.filter((item) => item.quantity > 0);
  const all_lines_resolved =
    activeLines.length > 0 && activeLines.every((item) => isDropshipLineResolved(item));
  const total_delivered_qty = items.reduce(
    (sum, item) => sum + Number(item.confirmed_quantity ?? 0),
    0,
  );

  const order =
    codCollectAmount != null
      ? { ...detail.order, cod_collect_amount: codCollectAmount }
      : detail.order;
  const summary =
    codCollectAmount != null
      ? { ...detail.summary, cod_collect_amount: Number(codCollectAmount) }
      : detail.summary;

  return {
    ...detail,
    order,
    items,
    summary,
    computed: {
      ...detail.computed,
      all_lines_resolved,
      total_delivered_qty,
    },
  };
}
