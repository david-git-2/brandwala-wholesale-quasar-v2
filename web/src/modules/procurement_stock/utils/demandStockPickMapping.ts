import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import type { PreorderDemandStockPick } from '../repositories/procurementDemandRepository';
import { createDemandPickClientKey } from './demandStockPickClientKey';

export type DeliveryPaperPickRow = {
  client_key?: string | null;
  global_stock_id: number;
  quantity: number;
  close_action?: string | null;
  is_close_split?: boolean | null;
  shipment_name?: string | null;
  location_name?: string | null;
};

export const mapStockPicksFromApi = (
  picks?: PreorderDemandStockPick[],
): DemandStockPickSelection[] => {
  const seenStockIds = new Set<number>();
  return (picks ?? []).map((pick) => {
    const globalStockId = Number(pick.global_stock_id);
    const isCloseSplit = pick.close_split === true || seenStockIds.has(globalStockId);
    seenStockIds.add(globalStockId);
    const initialQuantity = isCloseSplit
      ? undefined
      : (pick.initial_quantity ?? pick.quantity);
    return {
      clientKey: createDemandPickClientKey(),
      globalStockId,
      shipmentName: pick.shipment_name ?? '',
      locationName: pick.location_name ?? '',
      quantity: pick.quantity,
      initialQuantity,
      closeAction: (pick.close_action ?? 'take') as DemandStockPickSelection['closeAction'],
      isCloseSplit,
      invoiceId: pick.invoice_id ?? null,
      returnedAt: pick.returned_at ?? null,
    };
  });
};

export const mapPaperPicksFromApi = (
  picks?: DeliveryPaperPickRow[] | null,
): DemandStockPickSelection[] =>
  (picks ?? []).map((pick) => ({
    clientKey: pick.client_key?.trim() || createDemandPickClientKey(),
    globalStockId: Number(pick.global_stock_id),
    shipmentName: pick.shipment_name ?? '',
    locationName: pick.location_name ?? '',
    quantity: pick.quantity,
    closeAction: (pick.close_action ?? null) as DemandStockPickSelection['closeAction'],
    isCloseSplit: Boolean(pick.is_close_split),
  }));

export const mapStockPicksToSavePayload = (
  picks: DemandStockPickSelection[],
): Array<{
  global_stock_id: number;
  quantity: number;
  close_action?: string | null;
  is_close_split?: boolean;
}> =>
  picks
    .filter((pick) => !pick.isCloseSplit || pick.quantity > 0)
    .map((pick) => ({
      global_stock_id: pick.globalStockId,
      quantity: pick.quantity,
      close_action: pick.closeAction ?? null,
      ...(pick.isCloseSplit ? { is_close_split: true } : {}),
    }));
