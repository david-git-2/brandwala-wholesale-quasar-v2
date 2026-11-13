import { computed, ref, watch, type Ref } from 'vue';
import type { CashbookLegPotChipOption } from './useCashbookLegPots';
import { useBooksExchangeRateQuery } from './useBooksExchangeRateQuery';
import type { MoneyPayKind } from '../types/moneyPayDialog';
import {
  currenciesMatch,
  needsPayoutBooksFx,
  needsPayoutSeparateBooksFx,
  needsPayoutTransactionRate,
} from '../utils/apPayoutFx';

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
  const transactionRate = ref<number | null>(null);
  const booksExchangeRate = ref<number | null>(null);

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

  const needsTransactionRate = computed(() =>
    needsPayoutTransactionRate(paymentCurrency.value, sourceCurrency.value),
  );

  const needsBooksFx = computed(() =>
    needsPayoutBooksFx(paymentCurrency.value, booksCurrency.value),
  );

  const needsSeparateBooksFx = computed(() =>
    needsPayoutSeparateBooksFx(
      paymentCurrency.value,
      sourceCurrency.value,
      booksCurrency.value,
    ),
  );

  const needsAnyFx = computed(
    () => needsTransactionRate.value || needsSeparateBooksFx.value,
  );

  const paymentBooksRateQuery = useBooksExchangeRateQuery(
    options.booksTenantId,
    paymentCurrency,
    computed(
      () =>
        fxActive.value
        && needsBooksFx.value
        && !currenciesMatch(paymentCurrency.value, booksCurrency.value),
    ),
  );

  const sourceBooksRateQuery = useBooksExchangeRateQuery(
    options.booksTenantId,
    sourceCurrency,
    computed(
      () =>
        fxActive.value
        && needsTransactionRate.value
        && !currenciesMatch(sourceCurrency.value, booksCurrency.value),
    ),
  );

  const resetFx = () => {
    transactionRate.value = needsTransactionRate.value ? null : 1;
    booksExchangeRate.value = null;
  };

  const applyPotBooksRates = () => {
    if (!options.dialogOpen.value || options.kind.value !== 'payment') return;
    const potRate = potBooksRate(options.fromPotId.value, options.fromPotOptions.value);
    if (potRate == null) return;
    if (needsSeparateBooksFx.value) {
      booksExchangeRate.value = potRate;
    } else if (needsTransactionRate.value) {
      transactionRate.value = potRate;
    } else if (needsBooksFx.value) {
      booksExchangeRate.value = potRate;
    }
  };

  const resolvedFromPotBooksRate = computed(() =>
    potBooksRate(options.fromPotId.value, options.fromPotOptions.value),
  );

  const resolvedBooksExchangeRate = (): number => {
    const fromRef = Number(booksExchangeRate.value);
    if (Number.isFinite(fromRef) && fromRef > 0) return fromRef;
    return resolvedFromPotBooksRate.value ?? 0;
  };

  const resolvedTransactionRate = (): number => {
    const fromRef = Number(transactionRate.value);
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
      if (needsSeparateBooksFx.value) {
        if (booksExchangeRate.value == null) booksExchangeRate.value = rate;
      } else if (needsTransactionRate.value && currenciesMatch(sourceCurrency.value, booksCurrency.value)) {
        if (transactionRate.value == null) transactionRate.value = rate;
      }
    },
  );

  watch(
    () => sourceBooksRateQuery.data.value,
    (rate) => {
      if (rate == null || rate <= 0) return;
      if (needsTransactionRate.value && !currenciesMatch(sourceCurrency.value, booksCurrency.value)) {
        if (transactionRate.value == null) transactionRate.value = rate;
      }
    },
  );

  watch([sourceCurrency, paymentCurrency, () => options.fromPotId.value, () => options.toPotId.value], () => {
    if (!options.dialogOpen.value) return;
    if (!needsTransactionRate.value) transactionRate.value = 1;
    else if (transactionRate.value === 1) transactionRate.value = null;
    if (!needsSeparateBooksFx.value) booksExchangeRate.value = null;
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
    if (needsTransactionRate.value && resolvedTransactionRate() <= 0) {
      return needsSeparateBooksFx.value
        ? `No pot rate on file (${sourceCurrency.value} per 1 ${paymentCurrency.value})`
        : `No exchange rate on file (${booksCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    if (needsSeparateBooksFx.value && resolvedBooksExchangeRate() <= 0) {
      return `No exchange rate on file (${booksCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    return null;
  };

  const settlementFxFields = () => {
    if (!needsBooksFx.value) {
      return { exchangeRate: null as number | null, booksExchangeRate: null as number | null };
    }
    const booksRate = needsSeparateBooksFx.value
      ? resolvedBooksExchangeRate()
      : resolvedTransactionRate();
    return {
      exchangeRate: Number.isFinite(booksRate) && booksRate > 0 ? booksRate : null,
      booksExchangeRate: needsSeparateBooksFx.value ? booksRate : null,
    };
  };

  const sourceFxFields = () => ({
    sourceCurrencyCode: sourceCurrency.value,
    transactionRate: needsTransactionRate.value ? resolvedTransactionRate() : 1,
  });

  return {
    transactionRate,
    booksExchangeRate,
    validateFx,
    settlementFxFields,
    sourceFxFields,
    needsBooksFx,
  };
}
