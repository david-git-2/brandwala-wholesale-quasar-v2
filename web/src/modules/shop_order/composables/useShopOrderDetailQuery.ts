import {
  useQuery,
  useInfiniteQuery,
  useMutation,
  useQueryClient,
  keepPreviousData,
} from '@tanstack/vue-query';
import { computed, type MaybeRefOrGetter, toValue, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ShopOrderItem } from '../types';
import type { StaffShopOrderItemsPageCursor } from '../types/staffShopOrderDetail';

const STAFF_ORDER_ITEMS_PAGE_SIZE = 50;

export function useShopOrderDetailQuery(
  orderId: Ref<number>,
  options?: {
    enabled?: MaybeRefOrGetter<boolean>;
    /** When true (default), load line items in cursor pages of 50. Mutations still return full payloads. */
    paginateItems?: MaybeRefOrGetter<boolean>;
  },
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? null);
  const extraEnabled = options?.enabled;
  const paginateItems = computed(() => toValue(options?.paginateItems) ?? true);

  const flatQuery = useQuery({
    queryKey: computed(() => [
      ...shopOrderQueryKeys.orderDetail(tenantId.value, orderId.value),
      'all-items',
    ]),
    queryFn: () => shopOrderRepository.getShopOrderById(tenantId.value!, orderId.value),
    enabled: computed(() => {
      const base = !!tenantId.value && orderId.value > 0 && !paginateItems.value;
      if (!base) return false;
      if (extraEnabled === undefined) return true;
      return toValue(extraEnabled);
    }),
    staleTime: 15 * 1000,
  });

  const infiniteQuery = useInfiniteQuery({
    queryKey: computed(() => [
      ...shopOrderQueryKeys.orderDetail(tenantId.value, orderId.value),
      'items-page',
      STAFF_ORDER_ITEMS_PAGE_SIZE,
    ]),
    queryFn: async ({ pageParam }) => {
      const cursor = (pageParam as StaffShopOrderItemsPageCursor | null) ?? null;
      return shopOrderRepository.getShopOrderById(tenantId.value!, orderId.value, {
        itemsLimit: STAFF_ORDER_ITEMS_PAGE_SIZE,
        itemsCursor: cursor,
      });
    },
    getNextPageParam: (lastPage) =>
      lastPage.itemsMeta?.has_more && lastPage.itemsMeta.next_cursor
        ? lastPage.itemsMeta.next_cursor
        : undefined,
    initialPageParam: null as StaffShopOrderItemsPageCursor | null,
    enabled: computed(() => {
      const base = !!tenantId.value && orderId.value > 0 && paginateItems.value;
      if (!base) return false;
      if (extraEnabled === undefined) return true;
      return toValue(extraEnabled);
    }),
    staleTime: 15 * 1000,
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: false,
  });

  const data = computed(() => {
    if (paginateItems.value) {
      const pages = infiniteQuery.data.value?.pages ?? [];
      if (!pages.length) return undefined;
      const order = pages[0]!.order;
      const seen = new Set<number>();
      const items: ShopOrderItem[] = [];
      for (const page of pages) {
        for (const item of page.items) {
          if (seen.has(item.id)) continue;
          seen.add(item.id);
          items.push(item);
        }
      }
      const lastMeta = pages[pages.length - 1]?.itemsMeta ?? null;
      return { order, items, itemsMeta: lastMeta };
    }
    return flatQuery.data.value;
  });

  const isLoading = computed(() =>
    paginateItems.value ? infiniteQuery.isLoading.value : flatQuery.isLoading.value,
  );

  const isError = computed(() =>
    paginateItems.value ? infiniteQuery.isError.value : flatQuery.isError.value,
  );

  const error = computed(() =>
    paginateItems.value ? infiniteQuery.error.value : flatQuery.error.value,
  );

  const isFetching = computed(() =>
    paginateItems.value ? infiniteQuery.isFetching.value : flatQuery.isFetching.value,
  );

  const refetch = async () => {
    if (paginateItems.value) {
      await infiniteQuery.refetch();
      return infiniteQuery.data.value?.pages[0];
    }
    return flatQuery.refetch();
  };

  const hasNextItemsPage = computed(() =>
    paginateItems.value ? infiniteQuery.hasNextPage.value : false,
  );

  const isFetchingNextItemsPage = computed(() =>
    paginateItems.value ? infiniteQuery.isFetchingNextPage.value : false,
  );

  const fetchNextItemsPage = () => {
    if (!paginateItems.value || !infiniteQuery.hasNextPage.value) {
      return Promise.resolve(undefined);
    }
    return infiniteQuery.fetchNextPage();
  };

  return {
    data,
    isLoading,
    isError,
    error,
    refetch,
    isFetching,
    hasNextItemsPage,
    isFetchingNextItemsPage,
    fetchNextItemsPage,
  };
}

export function useCustomerShopOrderDetailQuery(orderId: Ref<number>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.orderDetail(tenantId.value, orderId.value)),
    queryFn: () => shopOrderRepository.getCustomerShopOrder(tenantId.value, orderId.value),
    enabled: computed(() => tenantId.value > 0 && orderId.value > 0),
    staleTime: 15 * 1000,
  });
}

export function useSendCustomerCounterMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
    }: {
      orderId: number;
      items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>;
    }) => {
      await shopOrderRepository.customerCounterOffer(orderId, items);
    },
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.orderDetailRoot(),
      });
      showSuccessNotification('Your response was sent.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to submit counter offer.', 'Action Failed');
    },
  });
}

export function useCustomerConfirmOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (orderId: number) => {
      await shopOrderRepository.customerConfirmShopOrder(orderId);
    },
    onSuccess: (_, orderId) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.orderDetailRoot(),
      });
      showSuccessNotification('Order confirmed successfully!');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to confirm order.', 'Action Failed');
    },
  });
}
