import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  procurementDemandRepository,
  type ProcurementDemandGroup,
} from '../repositories/procurementDemandRepository';

function invalidateDemandQueries(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroups'] });
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroupItems'] });
}

export function useMarkDemandGroupReadyMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (group: ProcurementDemandGroup) =>
      procurementDemandRepository.markDemandGroupReadyForShipment(group),
    onSuccess: () => invalidateDemandQueries(queryClient),
  });
}

export function useSetDemandGroupStatusMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (params: { group: ProcurementDemandGroup; tenantId: number }) =>
      procurementDemandRepository.setDemandGroupStatusReadyForShipment(params),
    onSuccess: () => invalidateDemandQueries(queryClient),
  });
}
