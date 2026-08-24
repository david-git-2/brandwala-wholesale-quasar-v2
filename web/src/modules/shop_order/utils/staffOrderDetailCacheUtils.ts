import type { QueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrder, ShopOrderItem } from '../types';
import type { StaffShopOrderDetailResponse } from '../types/staffShopOrderDetail';
import {
  mapStaffShopOrderDetailToFlat,
  parseStaffShopOrderDetailResponse,
} from './staffShopOrderDetailMapper';

export function applyStaffOrderDetailToCache(
  queryClient: QueryClient,
  tenantId: number,
  orderId: number,
  raw: StaffShopOrderDetailResponse | unknown,
): { order: ShopOrder; items: ShopOrderItem[] } {
  const flat = mapStaffShopOrderDetailToFlat(parseStaffShopOrderDetailResponse(raw));
  queryClient.setQueryData(shopOrderQueryKeys.orderDetail(tenantId, orderId), flat);
  return flat;
}
