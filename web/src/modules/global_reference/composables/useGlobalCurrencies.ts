import { computed, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useGlobalReferenceStore } from '../stores/globalReferenceStore';

/** Pinia-first global currencies — no API when the store already has rows. */
export function useGlobalCurrencies() {
  const store = useGlobalReferenceStore();
  const { currencies, loadingCurrencies, currenciesError } = storeToRefs(store);

  onMounted(() => {
    if (currencies.value.length === 0) {
      void store.ensureCurrenciesLoaded();
    }
  });

  const currencyOptions = computed(() =>
    currencies.value.map((c) => ({
      label: `${c.name} (${c.code})`,
      value: c.id,
    })),
  );

  return {
    currencies,
    currencyOptions,
    loadingCurrencies,
    currenciesError,
    ensureCurrenciesLoaded: () => store.ensureCurrenciesLoaded(),
    currencyById: (id: number) => store.currencyById(id),
    currencyByCode: (code: string) => store.currencyByCode(code),
  };
}
