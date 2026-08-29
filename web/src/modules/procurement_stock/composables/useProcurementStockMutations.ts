import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { globalShipmentRepository, type ShipmentOverviewDetailsPayload } from '../repositories/globalShipmentRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

/**
 * TanStack Mutation for Bulk Deleting Shipment Items
 */
export function useBulkDeleteShipmentItemsMutation(shipmentId: number) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (ids: number[]) =>
      globalShipmentRepository.deleteShipmentItemsBulk(shipmentId, ids),
    onSuccess: (_count, deletedIds) => {
      const idSet = new Set(deletedIds);
      queryClient.setQueryData(
        procurementStockQueryKeys.shipmentOverview(shipmentId),
        (old: ShipmentOverviewDetailsPayload | undefined) => {
          if (!old) return old;
          return {
            ...old,
            items: old.items.filter((item) => !idSet.has(item.id)),
          };
        },
      );
    },
  });
}

/**
 * TanStack Mutation for Updating a Shipment (Header/Metadata/Status)
 */
export function useUpdateShipmentMutation(shipmentId: number) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: Parameters<typeof globalShipmentRepository.updateShipment>[1]) =>
      globalShipmentRepository.updateShipment(shipmentId, payload),
    onSuccess: (updated) => {
      queryClient.setQueryData(
        procurementStockQueryKeys.shipmentOverview(shipmentId),
        (old: ShipmentOverviewDetailsPayload | undefined) => {
          if (!old) return old;
          return {
            ...old,
            shipment: {
              ...old.shipment,
              ...updated,
            },
          };
        },
      );
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'shipments'] });
    },
  });
}

/**
 * TanStack Mutation for Archiving a Shipment
 */
export function useArchiveShipmentMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (shipmentId: number) => globalShipmentRepository.archiveShipment(shipmentId),
    onSuccess: (archived) => {
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'shipments'] });
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'archivedShipments'] });
      queryClient.setQueryData(
        procurementStockQueryKeys.shipmentOverview(archived.id),
        (old: ShipmentOverviewDetailsPayload | undefined) => {
          if (!old) return old;
          return { ...old, shipment: { ...old.shipment, ...archived } };
        },
      );
    },
  });
}

/**
 * TanStack Mutation for Unarchiving a Shipment
 */
export function useUnarchiveShipmentMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (shipmentId: number) => globalShipmentRepository.unarchiveShipment(shipmentId),
    onSuccess: (restored) => {
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'shipments'] });
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'archivedShipments'] });
      queryClient.setQueryData(
        procurementStockQueryKeys.shipmentOverview(restored.id),
        (old: ShipmentOverviewDetailsPayload | undefined) => {
          if (!old) return old;
          return { ...old, shipment: { ...old.shipment, ...restored } };
        },
      );
    },
  });
}

/**
 * TanStack Mutation for Permanently Purging an Archived Shipment (Draft/Cancelled only)
 */
export function usePurgeArchivedShipmentMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (shipmentId: number) => globalShipmentRepository.purgeArchivedShipment(shipmentId),
    onSuccess: (_data, shipmentId) => {
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'shipments'] });
      queryClient.invalidateQueries({ queryKey: ['procurementStock', 'archivedShipments'] });
      queryClient.removeQueries({ queryKey: procurementStockQueryKeys.shipmentOverview(shipmentId) });
    },
  });
}
