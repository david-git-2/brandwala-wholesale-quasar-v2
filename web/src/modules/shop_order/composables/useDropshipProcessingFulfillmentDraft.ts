import { computed, ref, type Ref } from 'vue';
import type { ActiveStockPick } from '../repositories/shopOrderRepository';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { ShopOrderItem, ShopOrderItemStockPick } from '../types';
import { isDropshipLineResolved } from '../utils/dropshipInvoiceFulfillment';

export type FulfillmentLineDraft = {
  unavailable: boolean;
  picks: ActiveStockPick[];
};

let nextTempPickId = -1;

function allocTempPickId(): number {
  nextTempPickId -= 1;
  return nextTempPickId;
}

function stockPickToActive(pick: ShopOrderItemStockPick): ActiveStockPick {
  return {
    id: pick.id,
    global_stock_id: pick.global_stock_id,
    shipment_id: pick.shipment_id,
    shipment_name: pick.shipment_name ?? '',
    quantity: pick.quantity,
    unit_cost_amount: pick.unit_cost_amount ?? undefined,
    created_at: '',
  };
}

function lineDraftFromItem(item: ShopOrderItem): FulfillmentLineDraft {
  return {
    unavailable: item.is_fulfillment_unavailable === true,
    picks: (item.stock_picks ?? []).map(stockPickToActive),
  };
}

function serializeBaseline(lines: Record<number, FulfillmentLineDraft>): string {
  return JSON.stringify(lines);
}

function mergeItemWithDraft(item: ShopOrderItem, draft: FulfillmentLineDraft): ShopOrderItem {
  const pickQty = draft.picks.reduce((sum, p) => sum + p.quantity, 0);
  const stock_picks: ShopOrderItemStockPick[] = draft.picks.map((p) => ({
    id: p.id,
    global_stock_id: p.global_stock_id,
    shipment_id: p.shipment_id,
    shipment_name: p.shipment_name,
    shipment_item_id: 0,
    quantity: p.quantity,
    unit_cost_amount: p.unit_cost_amount ?? null,
  }));

  const merged: ShopOrderItem = {
    ...item,
    is_fulfillment_unavailable: draft.unavailable,
    confirmed_quantity: draft.unavailable ? 0 : pickQty,
    stock_picks,
    fulfillment_resolved: isDropshipLineResolved({
      quantity: item.quantity,
      confirmed_quantity: draft.unavailable ? 0 : pickQty,
      is_fulfillment_unavailable: draft.unavailable,
      is_gift: item.is_gift,
      gift_source: item.gift_source,
      stock_picks,
    }),
  };
  return merged;
}

export function useDropshipProcessingFulfillmentDraft(orderItems: Ref<ShopOrderItem[]>) {
  const lines = ref<Record<number, FulfillmentLineDraft>>({});
  const baselineSerialized = ref('');

  const resetFromServerItems = (items: ShopOrderItem[]) => {
    const next: Record<number, FulfillmentLineDraft> = {};
    for (const item of items) {
      if ((item.quantity ?? 0) <= 0) continue;
      if (item.is_gift && item.gift_source === 'stock') continue;
      next[item.id] = lineDraftFromItem(item);
    }
    lines.value = next;
    baselineSerialized.value = serializeBaseline(next);
  };

  const hasFulfillmentDraftChanges = computed(
    () => serializeBaseline(lines.value) !== baselineSerialized.value,
  );

  const displayOrderItems = computed(() =>
    orderItems.value.map((item) => {
      const draft = lines.value[item.id];
      if (!draft) return item;
      return mergeItemWithDraft(item, draft);
    }),
  );

  const draftPicksForItem = (itemId: number): ActiveStockPick[] => lines.value[itemId]?.picks ?? [];

  const setLine = (itemId: number, draft: FulfillmentLineDraft) => {
    lines.value = { ...lines.value, [itemId]: draft };
  };

  const addDraftPick = (
    itemId: number,
    row: {
      global_stock_id: number;
      shipment_id: number;
      shipment_name: string;
      unit_cost_amount: number;
    },
    quantity: number,
  ) => {
    const line = lines.value[itemId];
    if (!line || line.unavailable) return;

    const existing = line.picks.find((p) => p.global_stock_id === row.global_stock_id);
    const picks = existing
      ? line.picks.map((p) =>
          p.global_stock_id === row.global_stock_id
            ? { ...p, quantity: p.quantity + quantity }
            : p,
        )
      : [
          ...line.picks,
          {
            id: allocTempPickId(),
            global_stock_id: row.global_stock_id,
            shipment_id: row.shipment_id,
            shipment_name: row.shipment_name,
            quantity,
            unit_cost_amount: row.unit_cost_amount,
            created_at: '',
          },
        ];
    setLine(itemId, { ...line, picks });
  };

  const removeDraftPick = (itemId: number, pickId: number) => {
    const line = lines.value[itemId];
    if (!line) return;
    setLine(itemId, {
      ...line,
      picks: line.picks.filter((p) => p.id !== pickId),
    });
  };

  const markDraftUnavailable = (itemId: number) => {
    setLine(itemId, { unavailable: true, picks: [] });
  };

  const clearDraftUnavailable = (itemId: number) => {
    const line = lines.value[itemId];
    if (!line) return;
    setLine(itemId, { unavailable: false, picks: line.picks });
  };

  const discardFulfillmentDraft = () => {
    resetFromServerItems(orderItems.value);
  };

  const getFulfillmentCommitPayload = (): { lines: Array<{
    order_item_id: number;
    unavailable: boolean;
    picks: Array<{ global_stock_id: number; quantity: number }>;
  }> } | null => {
    if (serializeBaseline(lines.value) === baselineSerialized.value) {
      return null;
    }

    const commitLines: Array<{
      order_item_id: number;
      unavailable: boolean;
      picks: Array<{ global_stock_id: number; quantity: number }>;
    }> = [];

    for (const item of orderItems.value) {
      if ((item.quantity ?? 0) <= 0) continue;
      if (item.is_gift && item.gift_source === 'stock') continue;
      const draft = lines.value[item.id];
      if (!draft) continue;
      commitLines.push({
        order_item_id: item.id,
        unavailable: draft.unavailable,
        picks: draft.picks.map((p) => ({
          global_stock_id: p.global_stock_id,
          quantity: p.quantity,
        })),
      });
    }

    return { lines: commitLines };
  };

  const markFulfillmentCommitted = () => {
    baselineSerialized.value = serializeBaseline(lines.value);
  };

  const syncFulfillmentDraftToServer = async (): Promise<void> => {
    if (serializeBaseline(lines.value) === baselineSerialized.value) {
      return;
    }

    const baseline: Record<number, FulfillmentLineDraft> = JSON.parse(baselineSerialized.value || '{}');

    for (const item of orderItems.value) {
      if ((item.quantity ?? 0) <= 0) continue;
      if (item.is_gift && item.gift_source === 'stock') continue;

      const itemId = item.id;
      const was = baseline[itemId] ?? lineDraftFromItem(item);
      const now = lines.value[itemId] ?? was;

      if (now.unavailable) {
        for (const pick of was.picks) {
          if (pick.id > 0) {
            await shopOrderRepository.removeShopOrderItemStockPick(pick.id);
          }
        }
        if (!was.unavailable) {
          await shopOrderRepository.markShopOrderItemUnavailable(itemId, null, true);
        }
        continue;
      }

      if (was.unavailable) {
        await shopOrderRepository.clearShopOrderItemUnavailable(itemId);
      }

      for (const pick of was.picks) {
        if (pick.id > 0) {
          await shopOrderRepository.removeShopOrderItemStockPick(pick.id);
        }
      }

      for (const pick of now.picks) {
        await shopOrderRepository.addShopOrderItemStockPick(itemId, pick.global_stock_id, pick.quantity);
      }
    }

    baselineSerialized.value = serializeBaseline(lines.value);
  };

  return {
    displayOrderItems,
    hasFulfillmentDraftChanges,
    draftPicksForItem,
    addDraftPick,
    removeDraftPick,
    markDraftUnavailable,
    clearDraftUnavailable,
    discardFulfillmentDraft,
    syncFulfillmentDraftToServer,
    getFulfillmentCommitPayload,
    markFulfillmentCommitted,
    resetFromServerItems,
  };
}
