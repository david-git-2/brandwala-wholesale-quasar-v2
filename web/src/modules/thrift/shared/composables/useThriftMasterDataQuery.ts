import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftRepository } from '../repositories/thriftRepository';
import { thriftQueryKeys } from '../queryKeys/thriftQueryKeys';

const DEFAULT_STALE_TIME = 10 * 60 * 1000; // 10 minutes

function resolveEnabled(
  tenantId: Ref<number>,
  enabled?: Ref<boolean>,
) {
  return computed(() => !!tenantId.value && (enabled ? enabled.value : true));
}

export function useThriftCategoriesQuery(
  tenantId: Ref<number>,
  enabled?: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.categories(tenantId.value)),
    queryFn: () => thriftRepository.fetchCategories(tenantId.value),
    staleTime: DEFAULT_STALE_TIME,
    enabled: resolveEnabled(tenantId, enabled),
  });
}

export function useThriftTypesQuery(
  tenantId: Ref<number>,
  enabled?: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.types(tenantId.value)),
    queryFn: () => thriftRepository.fetchTypes(tenantId.value),
    staleTime: DEFAULT_STALE_TIME,
    enabled: resolveEnabled(tenantId, enabled),
  });
}

export function useThriftBoxesQuery(
  tenantId: Ref<number>,
  enabled?: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.boxes(tenantId.value)),
    queryFn: () => thriftRepository.fetchBoxes(tenantId.value),
    staleTime: DEFAULT_STALE_TIME,
    enabled: resolveEnabled(tenantId, enabled),
  });
}

export function useThriftShelvesQuery(
  tenantId: Ref<number>,
  enabled?: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.shelves(tenantId.value)),
    queryFn: () => thriftRepository.fetchShelves(tenantId.value),
    staleTime: DEFAULT_STALE_TIME,
    enabled: resolveEnabled(tenantId, enabled),
  });
}
