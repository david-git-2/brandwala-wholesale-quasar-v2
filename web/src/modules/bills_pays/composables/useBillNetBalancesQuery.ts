import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import { billsQueryKeys } from '../services/billsQueryKeys';
import type { BillNetBalances } from '../types/billBalances';

export type { BillNetBalances };

/** Prefer `get_bill_detail_bundle` on detail; use this only when bundle is not loaded. */
export function useBillNetBalancesQuery(billId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => [...billsQueryKeys.detail(billId.value), 'net-balances']),
    queryFn: async (): Promise<BillNetBalances> => {
      const id = billId.value;
      if (id == null || id <= 0) throw new Error('bill id required');
      const { data, error } = await supabase.rpc('get_bill_net_balances', { p_bill_id: id });
      if (error) throw error;
      return data as BillNetBalances;
    },
    enabled: computed(() => enabled.value && billId.value != null && billId.value > 0),
    staleTime: 20_000,
  });
}
