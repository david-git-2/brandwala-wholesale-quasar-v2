import { computed, watch, type Ref } from 'vue';
import type { CashbookLegPotChipOption } from './useCashbookLegPots';
import { useBooksExchangeRateQuery } from './useBooksExchangeRateQuery';
import { usePayoutFxCore } from './usePayoutFxCore';
import type { MoneyPayKind } from '../types/moneyPayDialog';
import { currenciesMatch } from '../utils/apPayoutFx';

function potCurrency(
  potId: number | null,
  options: CashbookLegPotChipOption[],
): string {
  if (potId == null) return '';
  const opt = options.find((o) => o.value === potId);
  return (opt?.currencyCode ?? '').trim().toUpperCase();
}

function potBooksRate(
  potId: number | null,
  options: CashbookLegPotChipOption[],
): number | null {
  if (potId == null) return null;
  const opt = options.find((o) => o.value === potId);
  const rate = opt?.booksRate;
  return rate != null && Number.isFinite(rate) && rate > 0 ? Number(rate) : null;
}

export function useMoneyPayDialogFx(options: {
  dialogOpen: Ref<boolean>;
  kind: Ref<MoneyPayKind>;
  showFromLeg: Ref<boolean>;
  fromPotId: Ref<number | null>;
  toPotId: Ref<number | null>;
  fromPotOptions: Ref<CashbookLegPotChipOption[]>;
  toPotOptions: Ref<CashbookLegPotChipOption[]>;
  paymentCurrencyCode: Ref<string>;
  booksCurrencyCode: Ref<string>;
  booksTenantId: Ref<number>;
}) {
  const paymentCurrency = computed(
    () => options.paymentCurrencyCode.value.trim().toUpperCase() || 'BDT',
  );
  const booksCurrency = computed(
    () => options.booksCurrencyCode.value.trim().toUpperCase() || 'BDT',
  );

  const sourceCurrency = computed(() => {
    if (options.kind.value !== 'payment') return booksCurrency.value;
    if (options.showFromLeg.value) {
      return potCurrency(options.fromPotId.value, options.fromPotOptions.value) || booksCurrency.value;
    }
    return potCurrency(options.toPotId.value, options.toPotOptions.value) || booksCurrency.value;
  });

  const fxActive = computed(
    () => options.dialogOpen.value && options.kind.value === 'payment' && sourceCurrency.value.length >= 3,
  );

  const {
    paymentToBooksRate,
    paymentToSourceRate,
    needsPaymentToSourceRate,
    needsPaymentToBooksFx,
    needsSeparateBooksRate,
    needsAnyFx,
    syncDefaultPaymentToSourceRate,
    effectivePaymentToBooksRate,
  } = usePayoutFxCore({
    paymentCurrency,
    sourceCurrency,
    booksCurrency,
    initialPaymentToSourceRate: null,
  });

  const paymentBooksRateQuery = useBooksExchangeRateQuery(
    options.booksTenantId,
    paymentCurrency,
    computed(
      () =>
        fxActive.value
        && needsPaymentToBooksFx.value
        && !currenciesMatch(paymentCurrency.value, booksCurrency.value),
    ),
  );

  const sourceBooksRateQuery = useBooksExchangeRateQuery(
    options.booksTenantId,
    sourceCurrency,
    computed(
      () =>
        fxActive.value
        && needsPaymentToSourceRate.value
        && !currenciesMatch(sourceCurrency.value, booksCurrency.value),
    ),
  );

  const resetFx = () => {
    paymentToSourceRate.value = needsPaymentToSourceRate.value ? null : 1;
    paymentToBooksRate.value = null;
  };

  const applyPotBooksRates = () => {
    if (!options.dialogOpen.value || options.kind.value !== 'payment') return;
    const potRate = potBooksRate(options.fromPotId.value, options.fromPotOptions.value);
    if (potRate == null) return;
    if (needsSeparateBooksRate.value) {
      paymentToBooksRate.value = potRate;
    } else if (needsPaymentToSourceRate.value) {
      paymentToSourceRate.value = potRate;
    } else if (needsPaymentToBooksFx.value) {
      paymentToBooksRate.value = potRate;
    }
  };

  const resolvedFromPotBooksRate = computed(() =>
    potBooksRate(options.fromPotId.value, options.fromPotOptions.value),
  );

  const resolvedPaymentToBooksRate = (): number => {
    const fromRef = Number(paymentToBooksRate.value);
    if (Number.isFinite(fromRef) && fromRef > 0) return fromRef;
    return resolvedFromPotBooksRate.value ?? 0;
  };

  const resolvedPaymentToSourceRate = (): number => {
    const fromRef = Number(paymentToSourceRate.value);
    if (Number.isFinite(fromRef) && fromRef > 0) return fromRef;
    return resolvedFromPotBooksRate.value ?? 0;
  };

  watch(
    () => options.dialogOpen.value,
    (open) => {
      if (open) {
        resetFx();
        applyPotBooksRates();
      }
    },
  );

  watch(
    () => paymentBooksRateQuery.data.value,
    (rate) => {
      if (rate == null || rate <= 0) return;
      if (needsSeparateBooksRate.value) {
        if (paymentToBooksRate.value == null) paymentToBooksRate.value = rate;
      } else if (needsPaymentToSourceRate.value && currenciesMatch(sourceCurrency.value, booksCurrency.value)) {
        if (paymentToSourceRate.value == null) paymentToSourceRate.value = rate;
      }
    },
  );

  watch(
    () => sourceBooksRateQuery.data.value,
    (rate) => {
      if (rate == null || rate <= 0) return;
      if (needsPaymentToSourceRate.value && !currenciesMatch(sourceCurrency.value, booksCurrency.value)) {
        if (paymentToSourceRate.value == null) paymentToSourceRate.value = rate;
      }
    },
  );

  watch([sourceCurrency, paymentCurrency, () => options.fromPotId.value, () => options.toPotId.value], () => {
    if (!options.dialogOpen.value) return;
    syncDefaultPaymentToSourceRate();
    if (!needsSeparateBooksRate.value) paymentToBooksRate.value = null;
  });

  watch(
    () => [options.dialogOpen.value, options.fromPotId.value, options.fromPotOptions.value] as const,
    () => {
      applyPotBooksRates();
    },
    { deep: true, immediate: true },
  );

  const validateFx = (): string | null => {
    if (!fxActive.value || !needsAnyFx.value) return null;
    if (needsPaymentToSourceRate.value && resolvedPaymentToSourceRate() <= 0) {
      return needsSeparateBooksRate.value
        ? `No pot rate on file (${sourceCurrency.value} per 1 ${paymentCurrency.value})`
        : `No exchange rate on file (${booksCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    if (needsSeparateBooksRate.value && resolvedPaymentToBooksRate() <= 0) {
      return `No exchange rate on file (${booksCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    return null;
  };

  const settlementFxFields = () => {
    if (!needsPaymentToBooksFx.value) {
      return { paymentToBooksRate: null as number | null, separateBooksRate: null as number | null };
    }
    const effectiveRate = effectivePaymentToBooksRate(
      resolvedPaymentToSourceRate(),
      resolvedPaymentToBooksRate(),
    );
    return {
      paymentToBooksRate: effectiveRate,
      separateBooksRate: needsSeparateBooksRate.value ? effectiveRate : null,
    };
  };

  const sourceFxFields = () => ({
    sourceCurrencyCode: sourceCurrency.value,
    paymentToSourceRate: needsPaymentToSourceRate.value ? resolvedPaymentToSourceRate() : 1,
  });

  return {
    paymentToSourceRate,
    paymentToBooksRate,
    validateFx,
    settlementFxFields,
    sourceFxFields,
    needsPaymentToBooksFx,
  };
}
