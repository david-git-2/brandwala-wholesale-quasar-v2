import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';

export function useBillSourceShipmentName(
  shipmentId: MaybeRefOrGetter<number | null | undefined>,
  enabled: MaybeRefOrGetter<boolean> = true,
) {
  const resolvedId = computed(() => {
    const raw = toValue(shipmentId);
    return raw != null && Number.isFinite(Number(raw)) && Number(raw) > 0 ? Number(raw) : null;
  });

  const isEnabled = computed(() => toValue(enabled) && resolvedId.value != null);

  const query = useQuery({
    queryKey: computed(() => ['bill-source-shipment-name', resolvedId.value] as const),
    queryFn: async () => {
      const id = resolvedId.value!;
      const { data, error } = await supabase
        .from('global_shipments')
        .select('name')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      const name = (data?.name ?? '').trim();
      return name || null;
    },
    enabled: isEnabled,
    staleTime: 5 * 60 * 1000,
  });

  const shipmentName = computed(() => query.data.value ?? null);

  return { shipmentName, isLoading: query.isPending };
}
