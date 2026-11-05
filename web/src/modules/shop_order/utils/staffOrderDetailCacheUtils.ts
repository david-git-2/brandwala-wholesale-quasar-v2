import type { QueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  mapStaffShopOrderDetailToFlat,
  parseStaffShopOrderDetailResponse,
} from './staffShopOrderDetailMapper';

const STAFF_ORDER_ITEMS_PAGE_SIZE = 50;

export function applyStaffOrderDetailToCache(
  queryClient: QueryClient,
  tenantId: number,
  orderId: number,
  raw: unknown,
): { order: ShopOrder; items: ShopOrderItem[] } {
  const flat = mapStaffShopOrderDetailToFlat(parseStaffShopOrderDetailResponse(raw));
  const detailKey = shopOrderQueryKeys.orderDetail(tenantId, orderId);

  queryClient.setQueryData([...detailKey, 'all-items'], flat);
  queryClient.setQueryData([...detailKey, 'items-page', STAFF_ORDER_ITEMS_PAGE_SIZE], {
    pages: [flat],
    pageParams: [null],
  });

  return flat;
}
