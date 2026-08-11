import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import {
  thriftCustomersRepository,
  type ListThriftCustomersParams,
} from '../repositories/thriftCustomersRepository';

export function useThriftCustomersQuery(params: Ref<ListThriftCustomersParams>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.customers(params.value)),
    queryFn: () => thriftCustomersRepository.list(params.value),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
