import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  procurementDemandRepository,
  type ClosePreorderDemandDocumentResult,
  type PreorderDemandCloseAction,
  type ProcurementDemandDocumentType,
} from '../repositories/procurementDemandRepository';

function invalidateDemandQueries(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroups'] });
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroupItems'] });
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'fulfillGroups'] });
  void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'fulfillGroupItems'] });
}

export type ClosePreorderDemandDocumentInput = {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  closeAction: PreorderDemandCloseAction;
};

export function useClosePreorderDemandDocumentMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: ClosePreorderDemandDocumentInput) =>
      procurementDemandRepository.closePreorderDemandDocument(input),
    onSuccess: () => invalidateDemandQueries(queryClient),
  });
}

export type { ClosePreorderDemandDocumentResult };
