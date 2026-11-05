import { useQuery } from '@tanstack/vue-query';
import { computed, unref, type MaybeRef } from 'vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type {
  CatalogOrderDeliveryPaperQtyByItem,
  CatalogOrderItemDeliveryPaperQty,
} from '../types/catalogOrderDeliveryPaperQty';

function parseDeliveryPaperEntry(raw: unknown): CatalogOrderItemDeliveryPaperQty | null {
  if (!raw || typeof raw !== 'object') return null;
  const row = raw as Record<string, unknown>;
  const deliveryPaperId = Number(row.delivery_paper_id);
  if (!Number.isFinite(deliveryPaperId) || deliveryPaperId <= 0) return null;
  const intField = (key: string): number => {
    const n = Math.trunc(Number(row[key] ?? 0));
    return Number.isFinite(n) && n > 0 ? n : 0;
  };
  const quantity = intField('quantity');
  const packedQty = intField('packed_qty') || intField('quantity');
  return {
    delivery_paper_id: deliveryPaperId,
    paper_status: String(row.paper_status ?? ''),
    quantity,
    packed_qty: packedQty,
    accepted_qty: intField('accepted_qty'),
    conditioned_qty: intField('conditioned_qty'),
    rejected_qty: intField('rejected_qty'),
  };
}

function parseDeliveryPaperQtyByItem(raw: unknown): CatalogOrderDeliveryPaperQtyByItem {
  if (!raw || typeof raw !== 'object') return {};
  const out: CatalogOrderDeliveryPaperQtyByItem = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    if (!Array.isArray(value)) continue;
    const entries = value
      .map(parseDeliveryPaperEntry)
      .filter((entry): entry is CatalogOrderItemDeliveryPaperQty => entry != null);
    if (entries.length) out[key] = entries;
  }
  return out;
}

export function useCatalogOrderDeliveryPaperQtyByItem(options: {
  tenantId: MaybeRef<number | null>;
  orderId: MaybeRef<number | null>;
  enabled?: MaybeRef<boolean>;
}) {
  const tenantId = computed(() => unref(options.tenantId));
  const orderId = computed(() => unref(options.orderId));
  const enabled = computed(
    () =>
      (unref(options.enabled) ?? true) &&
      tenantId.value != null &&
      orderId.value != null &&
      orderId.value > 0,
  );

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.deliveryPaperQtyByOrderItem(tenantId.value ?? 0, orderId.value ?? 0),
    ),
    queryFn: async () => {
      const raw = await shopOrderRepository.listShopOrderDeliveryPaperQtyByItem(
        tenantId.value!,
        orderId.value!,
      );
      return parseDeliveryPaperQtyByItem(raw);
    },
    enabled,
    staleTime: 0,
  });

  const byOrderItemId = computed(() => query.data.value ?? {});

  const entriesForOrderItem = (orderItemId: number): CatalogOrderItemDeliveryPaperQty[] =>
    byOrderItemId.value[String(orderItemId)] ?? [];

  return {
    byOrderItemId,
    entriesForOrderItem,
    isLoading: computed(() => query.isLoading.value),
    isError: computed(() => query.isError.value),
    refetch: query.refetch,
  };
}
