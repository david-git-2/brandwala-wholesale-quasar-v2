import { computed, ref, watch, type Ref } from 'vue';
import { amountsMatchToCent, computePayoutBooksTotal } from '../utils/apPayoutFx';
import { usePayoutFxCore } from './usePayoutFxCore';

/**
 * Pay-out / refund FX fields with explicit amount tracking in `paymentCurrency` and `booksCurrency`.
 */
export function useApPayoutFxFields(
  sourceCurrency: Ref<string>,
  booksAmount: Ref<number | null>,
  booksCurrency: Ref<string>,
  options?: {
    booksTenantId?: Ref<number>;
    active?: Ref<boolean>;
  },
) {
  const paymentCurrency = ref('BDT');
  const paymentAmount = ref<number | null>(null);

  const {
    paymentToBooksRate,
    paymentToSourceRate,
    needsPaymentToSourceRate,
    needsPaymentToBooksFx,
    needsSeparateBooksRate,
    sourceToPaymentHint,
    sourceToPaymentRateLabel,
    paymentToBooksRateLabel,
    syncDefaultPaymentToSourceRate,
    effectivePaymentToBooksRate,
    applyPrefilledRates,
  } = usePayoutFxCore({
    paymentCurrency,
    sourceCurrency,
    booksCurrency,
    initialPaymentToSourceRate: 1,
    ...(options?.booksTenantId ? { booksTenantId: options.booksTenantId } : {}),
    ...(options?.active ? { autoFetchActive: options.active } : {}),
  });

  const computedBooksAmount = computed(() =>
    computePayoutBooksTotal({
      paymentCurrency: paymentCurrency.value,
      sourceCurrency: sourceCurrency.value,
      booksCurrency: booksCurrency.value,
      paymentAmount: paymentAmount.value,
      paymentToSourceRate: paymentToSourceRate.value,
      paymentToBooksRate: paymentToBooksRate.value,
    }),
  );

  watch([paymentCurrency, sourceCurrency], syncDefaultPaymentToSourceRate);

  watch(
    [paymentCurrency, paymentAmount, paymentToBooksRate, paymentToSourceRate, sourceCurrency],
    () => {
      if (!needsPaymentToBooksFx.value) {
        paymentAmount.value = null;
        paymentToBooksRate.value = null;
        return;
      }
      if (!needsSeparateBooksRate.value) {
        paymentToBooksRate.value = null;
      }
      if (computedBooksAmount.value != null) {
        booksAmount.value = computedBooksAmount.value;
      }
    },
  );

  const resetFxAmounts = () => {
    paymentAmount.value = null;
    paymentToBooksRate.value = null;
    paymentToSourceRate.value = needsPaymentToSourceRate.value ? null : 1;
    applyPrefilledRates();
  };

  const validateFxFields = (): string | null => {
    if (needsPaymentToSourceRate.value && (paymentToSourceRate.value ?? 0) <= 0) {
      return `Enter transaction rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`;
    }
    if (needsPaymentToBooksFx.value) {
      if ((paymentAmount.value ?? 0) <= 0) return 'Enter amount in payment currency';
      if (needsSeparateBooksRate.value && (paymentToBooksRate.value ?? 0) <= 0) {
        return `Enter exchange rate to ${booksCurrency.value}`;
      }
      const books = computedBooksAmount.value;
      if (books == null) {
        return needsSeparateBooksRate.value
          ? 'Enter payment currency amount and books rate'
          : 'Enter payment currency amount and transaction rate';
      }
      if (!amountsMatchToCent(booksAmount.value, books)) {
        return `Books amount (${booksCurrency.value}) must match payment currency × rate`;
      }
    }
    return null;
  };

  const settlementFxPayload = () => ({
    settlement_currency_code: paymentCurrency.value,
    foreign_amount: needsPaymentToBooksFx.value ? Number(paymentAmount.value) : null,
    exchange_rate: effectivePaymentToBooksRate(),
  });

  const sourceFxPayload = (cashbookPointPotId: number | null) => ({
    source_currency_code: sourceCurrency.value,
    transaction_rate: needsPaymentToSourceRate.value ? Number(paymentToSourceRate.value) : 1,
    cashbook_point_pot_id: cashbookPointPotId,
  });

  return {
    paymentCurrency,
    paymentAmount,
    paymentToBooksRate,
    paymentToSourceRate,
    needsPaymentToSourceRate,
    sourceToPaymentHint,
    sourceToPaymentRateLabel,
    paymentToBooksRateLabel,
    needsPaymentToBooksFx,
    needsSeparateBooksRate,
    computedBooksAmount,
    resetFxAmounts,
    validateFxFields,
    settlementFxPayload,
    sourceFxPayload,
  };
}
