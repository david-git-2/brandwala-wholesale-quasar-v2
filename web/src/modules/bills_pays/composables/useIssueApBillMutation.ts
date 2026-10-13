import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  issueShipmentApBillForKind,
  type ShipmentApKind,
} from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useIssueApBillMutation(billId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { shipmentId: number; apKind: ShipmentApKind }) => {
      await issueShipmentApBillForKind(payload.shipmentId, payload.apKind);
    },
    onSuccess: () => {
      const id = billId();
      showSuccessNotification('Invoice issued.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
        void queryClient.invalidateQueries({ queryKey: [...billsQueryKeys.detail(id), 'net-balances'] });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
      }
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not issue invoice.';
      showErrorNotification(message);
    },
  });
}
