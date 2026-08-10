import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  thriftCourierRepository,
  type ThriftCourierProviderInput,
} from '../repositories/thriftCourierRepository';

export function thriftCourierQueryKey(tenantId: number | null | undefined) {
  return ['thrift', 'couriers', tenantId ?? 0] as const;
}

export function useThriftCourierPickerQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => thriftCourierQueryKey(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    queryFn: () => thriftCourierRepository.listForPicker(tenantId.value as number),
  });
}

export function useThriftCourierManageQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => [...thriftCourierQueryKey(tenantId.value), 'manage'] as const),
    enabled: computed(() => !!tenantId.value),
    queryFn: () => thriftCourierRepository.listForManage(tenantId.value as number),
  });
}

export function useThriftCourierMutations(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  const invalidate = () => {
    void queryClient.invalidateQueries({ queryKey: ['thrift', 'couriers'] });
  };

  const createMutation = useMutation({
    mutationFn: (input: ThriftCourierProviderInput) =>
      thriftCourierRepository.createCustom(tenantId.value as number, input),
    onSuccess: invalidate,
  });

  const updateMutation = useMutation({
    mutationFn: (payload: { id: number; input: Partial<ThriftCourierProviderInput> }) =>
      thriftCourierRepository.updateCustom(tenantId.value as number, payload.id, payload.input),
    onSuccess: invalidate,
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) =>
      thriftCourierRepository.deleteCustom(tenantId.value as number, id),
    onSuccess: invalidate,
  });

  return { createMutation, updateMutation, deleteMutation };
}
