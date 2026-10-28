import { useQueryClient } from '@tanstack/vue-query';
import { toValue, type MaybeRefOrGetter } from 'vue';
import { billsQueryKeys } from 'src/modules/bills_pays/services/billsQueryKeys';
import { paysQueryKeys } from 'src/modules/bills_pays/services/paysQueryKeys';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import {
  displayDueAmount,
  sumApBillsDue,
} from '../utils/shipmentApBillDisplay';
import type { ShipmentApBillRow } from '../repositories/shipmentApBillsRepository';

export { displayDueAmount, sumApBillsDue };

export function useShipmentApFinanceInvalidation() {
  const queryClient = useQueryClient();

  const invalidateAfterApPay = (shipmentId: number | null | undefined) => {
    void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root, refetchType: 'none' });
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root, refetchType: 'none' });
    if (shipmentId == null || !Number.isFinite(shipmentId)) return;
    void queryClient.invalidateQueries({
      queryKey: procurementStockQueryKeys.shipmentOverview(shipmentId),
    });
    void queryClient.invalidateQueries({
      queryKey: procurementStockQueryKeys.shipmentCostEntries(shipmentId),
    });
  };

  return { invalidateAfterApPay };
}

/** Shipment AP read + post-pay invalidation; finance rows live on `globalShipmentStore`. */
export function useShipmentApFinance(shipmentId: MaybeRefOrGetter<number | null | undefined>) {
  const store = useGlobalShipmentStore();
  const { invalidateAfterApPay } = useShipmentApFinanceInvalidation();

  const load = () => {
    const id = toValue(shipmentId);
    if (id == null || !Number.isFinite(id)) {
      return Promise.reject(new Error('Shipment id is required'));
    }
    return store.loadSettingsFinanceBundle(id);
  };

  return {
    load,
    displayDue: displayDueAmount,
    apBillsDueTotal,
    invalidateAfterApPay,
  };
}

export function apBillsDueTotal(bills: ShipmentApBillRow[]): number {
  return sumApBillsDue(bills);
}
