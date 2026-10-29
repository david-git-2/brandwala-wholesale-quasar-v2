import { computed, watch, type MaybeRefOrGetter, toValue } from 'vue';
import {
  useGlobalPaymentMethodsQuery,
  useBdBanksQuery,
} from 'src/modules/global_reference/composables/useGlobalReferenceQuery';

export type WholesaleMethodOption = {
  label: string;
  value: string;
  code: string;
  category: string;
};

export function useWholesalePaymentMethodMeta(
  defaultMethodCode = 'cash',
  enabled: MaybeRefOrGetter<boolean> = true,
) {
  const enabledRef = computed(() => toValue(enabled));

  const methodsQuery = useGlobalPaymentMethodsQuery();
  const banksQuery = useBdBanksQuery();

  const methodOptions = computed((): WholesaleMethodOption[] => {
    const methods = methodsQuery.data.value ?? [];
    return methods
      .filter((m) => m.scope === 'bd' || m.scope === 'both')
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((m) => ({
        label: m.name,
        value: m.code.toLowerCase(),
        code: m.code.toUpperCase(),
        category: m.category,
      }));
  });

  const bdBankOptions = computed(() => {
    const banks = banksQuery.data.value ?? [];
    return banks
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((b) => ({ label: b.name, value: b.id }));
  });

  const loadingPaymentMeta = computed(
    () =>
      enabledRef.value &&
      ((methodsQuery.isFetching.value && !methodsQuery.data.value?.length) ||
        (banksQuery.isFetching.value && !banksQuery.data.value?.length)),
  );

  const syncPaymentMetaDefaults = (ensureMethod: (code: string) => void) => {
    if (!enabledRef.value) return;
    const options = methodOptions.value;
    if (!options.length) return;
    if (!options.some((m) => m.value === defaultMethodCode)) {
      const fallback =
        options.find((m) => m.value === 'cash')?.value ??
        options[0]?.value ??
        defaultMethodCode;
      ensureMethod(fallback);
    }
  };

  const loadPaymentMeta = async (ensureMethod: (code: string) => void) => {
    if (!enabledRef.value) return;
    await Promise.all([methodsQuery.refetch(), banksQuery.refetch()]);
    syncPaymentMetaDefaults(ensureMethod);
  };

  watch(
    [methodOptions, enabledRef],
    () => {
      if (enabledRef.value && methodOptions.value.length) {
        syncPaymentMetaDefaults(() => {});
      }
    },
    { immediate: true },
  );

  return {
    loadingPaymentMeta,
    methodOptions,
    bdBankOptions,
    syncPaymentMetaDefaults,
    loadPaymentMeta,
  };
}
