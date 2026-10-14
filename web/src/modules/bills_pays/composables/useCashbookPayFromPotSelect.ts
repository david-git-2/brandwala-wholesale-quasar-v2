import { computed, ref, watch, type Ref } from 'vue';
import { cashbookPointKindLabel } from '../constants/cashbookPointKinds';
import type { CashbookPointRow } from '../repositories/cashbookRepository';
import { useCashbookPointPotsBatchQuery } from './useCashbookPointPotsQuery';

/** One option per location currency pot (pay from location + source cash). */
export function useCashbookPayFromPotSelect(
  points: Ref<CashbookPointRow[] | undefined>,
  enabled: Ref<boolean>,
) {
  const selectedPotId = ref<number | null>(null);

  const activePoints = computed(() => (points.value ?? []).filter((p) => p.is_active));

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

  const payFromOptions = computed(() => {
    const pots = potsQuery.data.value ?? [];
    return pots
      .map((pot) => {
        const point = pointById.value.get(pot.cashbook_point_id);
        const pointLabel = point
          ? `${point.name} (${cashbookPointKindLabel(point.kind)})`
          : 'Location';
        return {
          label: `${pointLabel} — ${pot.currency_code}`,
          value: pot.id,
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
    const pots = potsQuery.data.value ?? [];
    if (!pots.length) {
      selectedPotId.value = null;
      return;
    }
    if (selectedPotId.value != null && pots.some((p) => p.id === selectedPotId.value)) {
      return;
    }
    const bdt = pots.find((p) => p.currency_code.toUpperCase() === 'BDT');
    selectedPotId.value = (bdt ?? pots[0]).id;
  };

  watch(() => potsQuery.data.value, () => syncDefaultPot(), { immediate: true });

  const loading = computed(
    () => potsQuery.isPending.value || potsQuery.isFetching.value,
  );

  return {
    selectedPotId,
    payFromOptions,
    cashbookPointId,
    sourceCurrencyCode,
    loading,
  };
}
