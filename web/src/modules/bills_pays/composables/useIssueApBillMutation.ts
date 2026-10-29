import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { issueShipmentApBillForKind } from 'src/modules/procurement_stock/repositories/shipmentMoneyKernelRepository';
import type { ShipmentApKind } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useIssueApBillMutation(billId: () => number | null) {
  const queryClient = useQueryClient();
  const shipmentStore = useGlobalShipmentStore();

  return useMutation({
    mutationFn: (payload: { shipmentId: number; apKind: ShipmentApKind }) =>
      issueShipmentApBillForKind(payload.shipmentId, payload.apKind),
    onSuccess: (bundle) => {
      const id = billId();
      showSuccessNotification('Invoice issued.');
      if (id) {
        queryClient.setQueryData(billsQueryKeys.detailBundle(id), bundle);
      }
      shipmentStore.settingsFinanceCachedShipmentId = null;
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root, refetchType: 'none' });
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not issue invoice.';
      showErrorNotification(message);
    },
  });
}
