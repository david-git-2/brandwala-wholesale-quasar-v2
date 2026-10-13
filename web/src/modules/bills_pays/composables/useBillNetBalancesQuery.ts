import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import { billsQueryKeys } from '../services/billsQueryKeys';

export type BillNetBalances = {
  bill_id: number;
  invoice_no: string;
  original_total: number;
  paid_amount: number;
  credits_issued: number;
  debits_issued: number;
  due_amount: number;
  credit_open: number;
  document_kind: string;
};

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
