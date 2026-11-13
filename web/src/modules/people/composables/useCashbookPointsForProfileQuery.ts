import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { cashbookQueryKeys } from 'src/modules/bills_pays/services/cashbookQueryKeys';

export function useCashbookPointsForProfileQuery(
  booksTenantId: Ref<number>,
  profileId: Ref<number | null>,
  enabled: Ref<boolean>,
) {
  const accountQuery = useQuery({
    queryKey: computed(() =>
      [...cashbookQueryKeys.root, 'account_profile', booksTenantId.value, profileId.value] as const,
    ),
    queryFn: async () => {
      const pid = profileId.value;
      if (pid == null) throw new Error('Profile not set.');
      let accountId = await cashbookRepository.resolveCashbookAccountIdForProfile(
        booksTenantId.value,
        pid,
      );
      if (accountId == null) {
        accountId = await cashbookRepository.ensureCashbookAccountForProfile(pid, 'BDT');
      }
      return accountId;
    },
    enabled: computed(
      () => enabled.value && booksTenantId.value > 0 && profileId.value != null,
    ),
    staleTime: 60_000,
  });

  const cashbookAccountId = computed(() => accountQuery.data.value ?? null);

  const pointsQuery = useQuery({
    queryKey: computed(() => cashbookQueryKeys.points(cashbookAccountId.value)),
    queryFn: () => cashbookRepository.listCashbookPoints(cashbookAccountId.value!),
    enabled: computed(() => enabled.value && cashbookAccountId.value != null),
    staleTime: 30_000,
  });

  return { accountQuery, pointsQuery, cashbookAccountId };
}
