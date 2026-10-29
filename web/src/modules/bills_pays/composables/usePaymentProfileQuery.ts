import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';

export type PaymentProfileParams = {
  tenantId: number;
  entityType: string;
  entityId: number;
  ledgerLimit?: number;
  paysLimit?: number;
};

export function usePaymentProfileQuery(params: Ref<PaymentProfileParams>) {
  const ready = computed(
    () => !!params.value.tenantId && !!params.value.entityId && !!params.value.entityType,
  );

  return useQuery({
    queryKey: computed(() =>
      cashbookQueryKeys.paymentProfile(
        params.value.tenantId,
        params.value.entityType,
        params.value.entityId,
        {
          ledgerLimit: params.value.ledgerLimit ?? 50,
          paysLimit: params.value.paysLimit ?? 50,
        },
      ),
    ),
    queryFn: () =>
      cashbookRepository.getPaymentProfileForStaff({
        tenantId: params.value.tenantId,
        entityType: params.value.entityType,
        entityId: params.value.entityId,
        ledgerLimit: params.value.ledgerLimit,
        paysLimit: params.value.paysLimit,
      }),
    enabled: ready,
    staleTime: 60_000,
    gcTime: 5 * 60_000,
  });
}
