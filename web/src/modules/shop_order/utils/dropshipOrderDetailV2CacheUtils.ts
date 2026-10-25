import type { QueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { DropshipOrderDetailV2Response } from './dropshipOrderDetailV2Mapper';
import { useDropshipOrderDetailV2Store } from '../stores/dropshipOrderDetailV2Store';
import type { ShopOrder, ShopOrderItem } from '../types';

export function applyDropshipOrderDetailV2ToCache(
  tenantId: number,
  orderId: number,
  raw: unknown,
): DropshipOrderDetailV2Response {
  return useDropshipOrderDetailV2Store().setDetailFromRaw(tenantId, orderId, raw);
}

export function patchDropshipOrderDetailV2Cache(
  tenantId: number,
  orderId: number,
  updater: (current: DropshipOrderDetailV2Response) => DropshipOrderDetailV2Response,
): void {
  useDropshipOrderDetailV2Store().patchDetail(tenantId, orderId, updater);
}

export function invalidateDropshipOrderDetailV2(tenantId: number, orderId: number): void {
  useDropshipOrderDetailV2Store().clearDetail(tenantId, orderId);
}

export function patchDropshipRecipientCallAttemptCount(
  queryClient: QueryClient,
  tenantId: number,
  orderId: number,
  recipientCallAttemptCount: number,
): void {
  patchDropshipOrderDetailV2Cache(tenantId, orderId, (detail) => ({
    ...detail,
    order: {
      ...detail.order,
      recipient_call_attempt_count: recipientCallAttemptCount,
    },
  }));

  type StaffDetailCache = { order: ShopOrder; items: ShopOrderItem[] };
  queryClient.setQueryData<StaffDetailCache | undefined>(
    shopOrderQueryKeys.orderDetail(tenantId, orderId),
    (prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        order: {
          ...prev.order,
          recipient_call_attempt_count: recipientCallAttemptCount,
        },
      };
    },
  );
}
