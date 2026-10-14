import { computed, ref, watch, type Ref } from 'vue';
import {
  computePayoutBooksAmount,
  currenciesMatch,
  needsPayoutBooksFx,
  needsPayoutSeparateBooksFx,
  needsPayoutTransactionRate,
} from '../utils/apPayoutFx';

/** Pay-out FX: payment currency (bill face) vs source currency (pot cash). */
export function useApPayoutFxFields(
  sourceCurrency: Ref<string>,
  amountBdt: Ref<number | null>,
  booksCurrencyCode: Ref<string>,
) {
  const paymentCurrency = ref('BDT');
  const foreignAmount = ref<number | null>(null);
  const booksExchangeRate = ref<number | null>(null);
  const transactionRate = ref<number | null>(1);

  const needsTransactionRate = computed(() =>
    needsPayoutTransactionRate(paymentCurrency.value, sourceCurrency.value),
  );

  const needsBooksFx = computed(() =>
    needsPayoutBooksFx(paymentCurrency.value, booksCurrencyCode.value),
  );

  const needsSeparateBooksFx = computed(() =>
    needsPayoutSeparateBooksFx(
      paymentCurrency.value,
      sourceCurrency.value,
      booksCurrencyCode.value,
    ),
  );

  /** Pot cash currency ≠ payment currency (e.g. BDT pot, GBP pay-out). */
  const needsCurrencyShift = needsTransactionRate;

  const currencyShiftHint = computed(() => {
    if (!needsTransactionRate.value) return '';
    const src = sourceCurrency.value;
    const pay = paymentCurrency.value;
    const books = booksCurrencyCode.value;
    if (currenciesMatch(src, books) && !currenciesMatch(pay, books)) {
      return `Cash leaves the pot in ${src}. You record this pay-out in ${pay}. Enter the rate between them.`;
    }
    return `Cash is in ${src}. Payment is in ${pay}. Enter how much ${src} per 1 ${pay}.`;
  });

  const potCashRateLabel = computed(
    () => `Rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`,
  );

  const booksCashRateLabel = computed(
    () => `${booksCurrencyCode.value} rate (per 1 ${paymentCurrency.value})`,
  );

  const computedBooksBdt = computed(() => {
    if (!needsBooksFx.value) return null;
    if (!needsSeparateBooksFx.value) {
      const foreign = foreignAmount.value;
      const rate = transactionRate.value;
      if (foreign == null || rate == null || foreign <= 0 || rate <= 0) return null;
      return Math.round(foreign * rate * 100) / 100;
    }
    return computePayoutBooksAmount(
      paymentCurrency.value,
      foreignAmount.value,
      booksExchangeRate.value,
      booksCurrencyCode.value,
    );
  });

  const syncTransactionRateDefault = () => {
    if (!needsTransactionRate.value) {
      transactionRate.value = 1;
    } else if (transactionRate.value === 1) {
      transactionRate.value = null;
    }
  };

  watch([paymentCurrency, sourceCurrency], syncTransactionRateDefault);

  watch(
    [paymentCurrency, foreignAmount, booksExchangeRate, transactionRate, sourceCurrency],
    () => {
      if (!needsBooksFx.value) {
        foreignAmount.value = null;
        booksExchangeRate.value = null;
        return;
      }
      if (!needsSeparateBooksFx.value) {
        booksExchangeRate.value = null;
      }
      if (computedBooksBdt.value != null) {
        amountBdt.value = computedBooksBdt.value;
      }
    },
  );

  const resetFxAmounts = () => {
    foreignAmount.value = null;
    booksExchangeRate.value = null;
    transactionRate.value = 1;
  };

  const validateFxFields = (): string | null => {
    if (needsTransactionRate.value) {
      if ((transactionRate.value ?? 0) <= 0) {
        return `Enter transaction rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`;
      }
    }
    if (needsBooksFx.value) {
      if ((foreignAmount.value ?? 0) <= 0) return 'Enter amount in payment currency';
      if (needsSeparateBooksFx.value && (booksExchangeRate.value ?? 0) <= 0) {
        return `Enter exchange rate to ${booksCurrencyCode.value}`;
      }
      const books = computedBooksBdt.value;
      if (books == null) {
        return needsSeparateBooksFx.value
          ? 'Enter payment currency amount and books rate'
          : 'Enter payment currency amount and transaction rate';
      }
      if (Math.round((amountBdt.value ?? 0) * 100) !== Math.round(books * 100)) {
        return `Books amount (${booksCurrencyCode.value}) must match payment currency × rate`;
      }
    }
    return null;
  };

  const settlementFxPayload = () => ({
    settlement_currency_code: paymentCurrency.value,
    foreign_amount: needsBooksFx.value ? Number(foreignAmount.value) : null,
    exchange_rate: needsBooksFx.value
      ? needsSeparateBooksFx.value
        ? Number(booksExchangeRate.value)
        : Number(transactionRate.value)
      : null,
  });

  const sourceFxPayload = (cashbookPointPotId: number | null) => ({
    source_currency_code: sourceCurrency.value,
    transaction_rate: needsTransactionRate.value ? Number(transactionRate.value) : 1,
    cashbook_point_pot_id: cashbookPointPotId,
  });

  return {
    paymentCurrency,
    foreignAmount,
    booksExchangeRate,
    transactionRate,
    needsTransactionRate,
    needsCurrencyShift,
    currencyShiftHint,
    potCashRateLabel,
    booksCashRateLabel,
    needsBooksFx,
    needsSeparateBooksFx,
    computedBooksBdt,
    resetFxAmounts,
    validateFxFields,
    settlementFxPayload,
    sourceFxPayload,
  };
};
