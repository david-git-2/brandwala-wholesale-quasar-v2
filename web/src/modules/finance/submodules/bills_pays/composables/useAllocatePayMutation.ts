import { useApplySettlementMutation } from './useApplySettlementMutation';

/** Pay leftover → bills via kernel `apply_settlement_to_bill` (pay allocator). */
export function useAllocatePayMutation() {
  return useApplySettlementMutation({ successMessage: 'Leftover applied to bills.' });
}
