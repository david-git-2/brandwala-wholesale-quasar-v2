import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  procurementDemandRepository,
  type ProcurementDemandGroup,
} from '../repositories/procurementDemandRepository';

export function useMarkDemandGroupReadyMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (group: ProcurementDemandGroup) =>
      procurementDemandRepository.markDemandGroupReadyForShipment(group),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroups'] });
    },
  });
}
