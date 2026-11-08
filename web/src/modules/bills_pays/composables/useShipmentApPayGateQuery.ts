import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';

export type ShipmentApPayGate = {
  id: number;
  status: string;
  costs_locked: boolean;
};

export function useShipmentApPayGateQuery(shipmentId: Ref<number | null | undefined>) {
  const query = useQuery({
    queryKey: computed(() => ['shipment-ap-pay-gate', shipmentId.value ?? null]),
    enabled: computed(() => shipmentId.value != null && shipmentId.value > 0),
    queryFn: async (): Promise<ShipmentApPayGate | null> => {
      const id = shipmentId.value;
      if (id == null || id <= 0) return null;
      const { data, error } = await supabase
        .from('global_shipments')
        .select('id, status, costs_locked')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      return data as ShipmentApPayGate | null;
    },
    staleTime: 30_000,
  });

  const payBlockedReason = computed((): string | null => {
    const row = query.data.value;
    if (!row) return null;
    if (row.status === 'draft' || row.status === 'cancelled') {
      return 'Set the shipment to in transit (or received) before recording AP payout.';
    }
    return null;
  });

  return { ...query, payBlockedReason };
}
