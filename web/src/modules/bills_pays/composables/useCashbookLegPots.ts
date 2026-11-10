import { computed, ref, watch, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import type { CashbookPointRow } from '../repositories/cashbookRepository';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { useCashbookPointPotsBatchQuery } from './useCashbookPointPotsQuery';
import { formatAmountBdt } from 'src/utils/currency';

export type CashbookLegPotChipOption = {
  label: string;
  value: number;
  pointId: number;
  currencyCode: string;
};

/** Points + pots for one money profile (chip labels include on-hand amount). */
export function useCashbookLegPots(
  profileId: Ref<number | null | undefined>,
  booksTenantId: Ref<number>,
  enabled: Ref<boolean>,
) {
  const selectedPotId = ref<number | null>(null);

  const accountQuery = useQuery({
    queryKey: computed(() =>
      [...cashbookQueryKeys.root, 'account_by_profile', booksTenantId.value, profileId.value ?? 0] as const,
    ),
    queryFn: () =>
      cashbookRepository.findCashbookAccountIdByProfile(
        booksTenantId.value,
        profileId.value!,
      ),
    enabled: computed(
      () =>
        enabled.value &&
        booksTenantId.value > 0 &&
        profileId.value != null &&
        profileId.value > 0,
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

  const activePoints = computed(() => (pointsQuery.data.value ?? []).filter((p) => p.is_active));
  const pointIds = computed(() => activePoints.value.map((p) => p.id));

  const potsQuery = useCashbookPointPotsBatchQuery(
    pointIds,
    computed(() => enabled.value && pointIds.value.length > 0),
  );

  const pointById = computed(() => {
    const map = new Map<number, CashbookPointRow>();
    for (const point of activePoints.value) {
      map.set(point.id, point);
    }
    return map;
  });

  const chipOptions = computed((): CashbookLegPotChipOption[] => {
    const pots = potsQuery.data.value ?? [];
    return pots
      .map((pot) => {
        const point = pointById.value.get(pot.cashbook_point_id);
        const pointLabel = point?.name ?? 'Location';
        const cur = pot.currency_code.trim().toUpperCase();
        return {
          label: `${pointLabel} · ${cur} ${formatAmountBdt(pot.amount)}`,
          value: pot.id,
          pointId: pot.cashbook_point_id,
          currencyCode: cur,
        };
      })
      .sort((a, b) => a.label.localeCompare(b.label));
  });

  const selectedPot = computed(() => {
    const id = selectedPotId.value;
    if (id == null) return null;
    return (potsQuery.data.value ?? []).find((p) => p.id === id) ?? null;
  });

  const cashbookPointId = computed(() => selectedPot.value?.cashbook_point_id ?? null);

  const sourceCurrencyCode = computed(
    () => selectedPot.value?.currency_code?.trim().toUpperCase() || 'BDT',
  );

  const syncDefaultPot = () => {
    const options = chipOptions.value;
    if (!options.length) {
      selectedPotId.value = null;
      return;
    }
    if (selectedPotId.value != null && options.some((o) => o.value === selectedPotId.value)) {
      return;
    }
    const bdt = options.find((o) => o.currencyCode === 'BDT');
    selectedPotId.value = (bdt ?? options[0]).value;
  };

  watch([chipOptions, profileId], syncDefaultPot, { immediate: true });

  const loading = computed(
    () =>
      accountQuery.isPending.value ||
      pointsQuery.isPending.value ||
      potsQuery.isPending.value ||
      potsQuery.isFetching.value,
  );

  return {
    selectedPotId,
    chipOptions,
    cashbookPointId,
    sourceCurrencyCode,
    loading,
  };
}
