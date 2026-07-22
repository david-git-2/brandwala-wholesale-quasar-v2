import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { type Ref } from 'vue';
import { thriftQueryKeys } from 'src/modules/thrift/shared/queryKeys/thriftQueryKeys';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';
import type { ThriftShipment } from '../types';

export function useCreateShipmentMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: Partial<ThriftShipment>) => thriftShipmentRepository.createShipment(input),
    onSuccess: () => {
      if (tenantId.value) {
        queryClient.invalidateQueries({ queryKey: thriftQueryKeys.shipments(tenantId.value) });
      }
    },
  });
}

export function useUpdateShipmentMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, input }: { id: number; input: Partial<ThriftShipment> }) =>
      thriftShipmentRepository.updateShipment(id, input),
    onSuccess: (data, variables) => {
      queryClient.setQueryData(thriftQueryKeys.shipmentDetail(String(variables.id)), data);
      if (tenantId.value) {
        queryClient.invalidateQueries({ queryKey: thriftQueryKeys.shipments(tenantId.value) });
      }
    },
  });
}

export function useDeleteShipmentMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => thriftShipmentRepository.deleteShipment(id),
    onSuccess: () => {
      if (tenantId.value) {
        queryClient.invalidateQueries({ queryKey: thriftQueryKeys.shipments(tenantId.value) });
      }
    },
  });
}
