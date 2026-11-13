import { computed } from 'vue';
import { SETTLEMENT_CURRENCY_SYMBOL } from 'src/utils/currency';
import { useMoneyKernelCurrenciesQuery } from './useMoneyKernelCurrenciesQuery';

export function useCurrencySymbolMap() {
  const currenciesQuery = useMoneyKernelCurrenciesQuery();

  const currencySymbolMap = computed(() => {
    const map = new Map<string, string>(Object.entries(SETTLEMENT_CURRENCY_SYMBOL));
    for (const row of currenciesQuery.data.value ?? []) {
      const code = row.code?.trim().toUpperCase();
      if (!code) continue;
      const symbol = row.symbol?.trim();
      if (symbol) map.set(code, symbol);
    }
    return map;
  });

  return { currencySymbolMap };
}
