import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import {
  thriftLedgerRepository,
  type ListThriftLedgerParams,
} from '../repositories/thriftLedgerRepository';

export type ThriftLedgerListQueryParams = ListThriftLedgerParams;

export function useThriftLedgerQuery(params: Ref<ThriftLedgerListQueryParams>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.ledger(params.value)),
    queryFn: () => thriftLedgerRepository.listEntries(params.value),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(
      () => !!params.value.tenantId && !!params.value.dateFrom && !!params.value.dateTo,
    ),
  });
}
