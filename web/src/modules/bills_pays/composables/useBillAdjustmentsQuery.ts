import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';
import { billsQueryKeys } from '../services/billsQueryKeys';

export type BillAdjustmentRow = Database['public']['Tables']['bills']['Row'];

export function useBillAdjustmentsQuery(
  parentBillId: Ref<number | null>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() => billsQueryKeys.adjustments(parentBillId.value)),
    queryFn: async (): Promise<BillAdjustmentRow[]> => {
      const id = parentBillId.value;
      if (id == null || id <= 0) throw new Error('bill id required');
      const { data, error } = await supabase.rpc('list_bill_adjustments', {
        p_parent_bill_id: id,
      });
      if (error) throw error;
      return (data ?? []) as BillAdjustmentRow[];
    },
    enabled: computed(
      () => enabled.value && parentBillId.value != null && parentBillId.value > 0,
    ),
    staleTime: 20_000,
  });
}
