import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from 'src/modules/thrift/shared/queryKeys/thriftQueryKeys';
import { thriftSettingsRepository } from '../repositories/thriftSettingsRepository';
import type { ThriftSettingsInput } from '../types';

export function useThriftSettingsQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.settings(tenantId.value ?? 0)),
    queryFn: () => thriftSettingsRepository.fetchSettings(tenantId.value!),
    staleTime: 10 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useUpdateThriftSettingsMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ThriftSettingsInput) =>
      thriftSettingsRepository.upsertSettings(tenantId.value!, input),
    onSuccess: (data) => {
      if (tenantId.value) {
        queryClient.setQueryData(thriftQueryKeys.settings(tenantId.value), data);
        return queryClient.invalidateQueries({ queryKey: thriftQueryKeys.settings(tenantId.value) });
      }
    },
  });
}
