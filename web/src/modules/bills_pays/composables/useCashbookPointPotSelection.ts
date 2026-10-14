import { computed, ref, watch, type Ref } from 'vue';
import { useCashbookPointPotsQuery } from './useCashbookPointPotsQuery';

/** Pick which currency pot pays from a cash point (source currency for pay out). */
export function useCashbookPointPotSelection(pointId: Ref<number | null>, enabled: Ref<boolean>) {
  const selectedPotId = ref<number | null>(null);

  const potsQuery = useCashbookPointPotsQuery(pointId, enabled);

  const pots = computed(() => potsQuery.data.value ?? []);

  const potOptions = computed(() =>
    pots.value.map((p) => ({
      label: p.currency_code,
      value: p.id,
    })),
  );

  const selectedPot = computed(() => {
    const id = selectedPotId.value;
    if (id == null) return null;
    return pots.value.find((p) => p.id === id) ?? null;
  });

  const sourceCurrencyCode = computed(() => {
    const code = selectedPot.value?.currency_code?.trim().toUpperCase();
    return code || 'BDT';
  });

  const syncDefaultPot = () => {
    const list = pots.value;
    if (!list.length) {
      selectedPotId.value = null;
      return;
    }
    if (list.length === 1) {
      selectedPotId.value = list[0].id;
      return;
    }
    if (selectedPotId.value != null && list.some((p) => p.id === selectedPotId.value)) {
      return;
    }
    const bdt = list.find((p) => p.currency_code.toUpperCase() === 'BDT');
    selectedPotId.value = (bdt ?? list[0]).id;
  };

  watch(pots, () => syncDefaultPot(), { immediate: true });

  watch(pointId, () => {
    selectedPotId.value = null;
    syncDefaultPot();
  });

  return {
    potsQuery,
    pots,
    potOptions,
    selectedPotId,
    selectedPot,
    sourceCurrencyCode,
    potsLoading: computed(() => potsQuery.isPending.value),
    hasMultiplePots: computed(() => pots.value.length > 1),
  };
}
