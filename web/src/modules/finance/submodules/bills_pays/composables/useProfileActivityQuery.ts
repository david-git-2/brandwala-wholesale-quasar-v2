import { computed, type Ref } from 'vue';
import { useInfiniteQuery } from '@tanstack/vue-query';
import {
  cashbookRepository,
  type ProfileActivityKind,
} from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export type ProfileActivityParams = {
  tenantId: number;
  entityType: string;
  entityId: number;
  kind: ProfileActivityKind;
  limit?: number;
};

export function useProfileActivityQuery(
  params: Ref<ProfileActivityParams>,
  enabled: Ref<boolean>,
) {
  return useInfiniteQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.profileActivity(
        params.value.tenantId,
        params.value.entityType,
        params.value.entityId,
        params.value.kind,
      ),
    ),
    queryFn: ({ pageParam }) =>
      cashbookRepository.listProfileActivity({
        tenantId: params.value.tenantId,
        entityType: params.value.entityType,
        entityId: params.value.entityId,
        kind: params.value.kind,
        limit: params.value.limit ?? 50,
        cursor: (pageParam as string | null | undefined) ?? null,
      }),
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    enabled,
    staleTime: 60_000,
  });
}
