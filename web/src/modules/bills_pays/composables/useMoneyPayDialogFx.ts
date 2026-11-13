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

  const showTransactionRateField = computed(() => needsTransactionRate.value);

  const showBooksExchangeRateField = computed(() => needsSeparateBooksFx.value);

  const showAnyFxField = computed(
    () => showTransactionRateField.value || showBooksExchangeRateField.value,
  );

  const transactionRateLabel = computed(() => {
    if (needsSeparateBooksFx.value) {
      return `Pot rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    return 'Exchange rate';
  });

  const transactionRateHint = computed(() => {
    if (!needsTransactionRate.value) return '';
    if (!needsSeparateBooksFx.value && needsBooksFx.value) {
      return `Also books in ${booksCurrency.value}: ${booksCurrency.value} per 1 ${paymentCurrency.value}`;
    }
    return `${sourceCurrency.value} per 1 ${paymentCurrency.value}`;
  });

  const booksExchangeRateLabel = computed(
    () => `Exchange rate (${booksCurrency.value} per 1 ${paymentCurrency.value})`,
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

  watch(
    () => options.dialogOpen.value,
    (open) => {
      if (open) resetFx();
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

  const validateFx = (): string | null => {
    if (!showAnyFxField.value) return null;
    if (needsTransactionRate.value) {
      if ((transactionRate.value ?? 0) <= 0) {
        return needsSeparateBooksFx.value
          ? `Enter pot rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`
          : 'Enter the exchange rate';
      }
    }
    if (needsSeparateBooksFx.value && (booksExchangeRate.value ?? 0) <= 0) {
      return `Enter exchange rate (${booksCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    return null;
  };

  const settlementFxFields = () => {
    if (!needsBooksFx.value) {
      return { exchangeRate: null as number | null, booksExchangeRate: null as number | null };
    }
    const booksRate = needsSeparateBooksFx.value
      ? Number(booksExchangeRate.value)
      : Number(transactionRate.value);
    return {
      exchangeRate: Number.isFinite(booksRate) && booksRate > 0 ? booksRate : null,
      booksExchangeRate: needsSeparateBooksFx.value ? booksRate : null,
    };
  };

  const sourceFxFields = () => ({
    sourceCurrencyCode: sourceCurrency.value,
    transactionRate: needsTransactionRate.value ? Number(transactionRate.value) : 1,
  });

  return {
    transactionRate,
    booksExchangeRate,
    showAnyFxField,
    showTransactionRateField,
    showBooksExchangeRateField,
    transactionRateLabel,
    transactionRateHint,
    booksExchangeRateLabel,
    validateFx,
    settlementFxFields,
    sourceFxFields,
    needsBooksFx,
  };
}
