import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { thriftBarcodeRepository } from '../repositories/thriftBarcodeRepository';
import type { ThriftBarcodeListParams } from '../types';

export type BarcodeQueryParams = ThriftBarcodeListParams;

export function useThriftBarcodesQuery(params: Ref<BarcodeQueryParams>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.barcodes(params.value)),
    queryFn: () => thriftBarcodeRepository.fetchBarcodesPaginated(params.value),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
