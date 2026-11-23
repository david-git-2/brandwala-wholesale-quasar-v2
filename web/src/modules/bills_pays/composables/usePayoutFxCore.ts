import { computed, ref, watch, type Ref } from 'vue';
import {
  currenciesMatch,
  derivePaymentToSourceCrossRate,
  needsPayoutBooksFx,
  needsPayoutSeparateBooksFx,
  needsPayoutTransactionRate,
} from '../utils/apPayoutFx';
import { useBooksExchangeRateQuery } from './useBooksExchangeRateQuery';

export interface PayoutFxCoreOptions {
  /** Bill face / settlement currency code. */
  paymentCurrency: Ref<string>;
  /** Cashbook pot / movement source currency code. */
  sourceCurrency: Ref<string>;
  /** Company ledger books currency code (usually `BDT`). */
  booksCurrency: Ref<string>;
  initialPaymentToSourceRate?: number | null;
  /** Optional tenant ID + active flag to auto-prefill rates from books exchange rates. */
  booksTenantId?: Ref<number>;
  autoFetchActive?: Ref<boolean>;
}

/**
 * Shared 3-way FX state and derivation for bills/cashbook payouts.
 *
 * Three currency roles:
 * - `paymentCurrency`: bill face / settlement currency
 * - `sourceCurrency`: cashbook pot / movement currency
 * - `booksCurrency`: company ledger currency (usually `BDT`)
 */
export function usePayoutFxCore(options: PayoutFxCoreOptions) {
  const { paymentCurrency, sourceCurrency, booksCurrency } = options;

  /** Units of `booksCurrency` per 1 unit of `paymentCurrency`. */
  const paymentToBooksRate = ref<number | null>(null);
  /** Units of `sourceCurrency` per 1 unit of `paymentCurrency`. */
  const paymentToSourceRate = ref<number | null>(
    options.initialPaymentToSourceRate === undefined ? 1 : options.initialPaymentToSourceRate,
  );

  const needsPaymentToSourceRate = computed(() =>
    needsPayoutTransactionRate(paymentCurrency.value, sourceCurrency.value),
  );

  const needsPaymentToBooksFx = computed(() =>
    needsPayoutBooksFx(paymentCurrency.value, booksCurrency.value),
  );

  const needsSeparateBooksRate = computed(() =>
    needsPayoutSeparateBooksFx(
      paymentCurrency.value,
      sourceCurrency.value,
      booksCurrency.value,
    ),
  );

  const needsAnyFx = computed(
    () => needsPaymentToSourceRate.value || needsSeparateBooksRate.value,
  );

  const autoFetchEnabled = computed(() => options.autoFetchActive?.value ?? true);
  const tenantIdRef = options.booksTenantId ?? ref(0);

  const paymentBooksRateQuery = useBooksExchangeRateQuery(
    tenantIdRef,
    paymentCurrency,
    computed(
      () =>
        tenantIdRef.value > 0
        && autoFetchEnabled.value
        && needsPaymentToBooksFx.value
        && !currenciesMatch(paymentCurrency.value, booksCurrency.value),
    ),
  );

  const sourceBooksRateQuery = useBooksExchangeRateQuery(
    tenantIdRef,
    sourceCurrency,
    computed(
      () =>
        tenantIdRef.value > 0
        && autoFetchEnabled.value
        && needsPaymentToSourceRate.value
        && !currenciesMatch(sourceCurrency.value, booksCurrency.value),
    ),
  );

  const applyPrefilledRates = () => {
    const payBooks = paymentBooksRateQuery.data.value;
    const srcBooks = sourceBooksRateQuery.data.value;
    if (payBooks != null && payBooks > 0) {
      if (needsSeparateBooksRate.value) {
        if (paymentToBooksRate.value == null) paymentToBooksRate.value = payBooks;
      } else if (
        needsPaymentToSourceRate.value
        && currenciesMatch(sourceCurrency.value, booksCurrency.value)
        && paymentToSourceRate.value == null
      ) {
        paymentToSourceRate.value = payBooks;
      }
    }
    if (
      needsPaymentToSourceRate.value
      && !currenciesMatch(sourceCurrency.value, booksCurrency.value)
      && paymentToSourceRate.value == null
    ) {
      const crossRate = derivePaymentToSourceCrossRate(payBooks, srcBooks);
      if (crossRate != null) {
        paymentToSourceRate.value = crossRate;
      } else if (srcBooks != null && srcBooks > 0 && currenciesMatch(paymentCurrency.value, booksCurrency.value)) {
        paymentToSourceRate.value = derivePaymentToSourceCrossRate(1, srcBooks);
      }
    }
  };

  watch(
    [
      () => paymentBooksRateQuery.data.value,
      () => sourceBooksRateQuery.data.value,
      paymentCurrency,
      sourceCurrency,
      booksCurrency,
    ],
    applyPrefilledRates,
    { immediate: true },
  );

  const sourceToPaymentHint = computed(() => {
    if (!needsPaymentToSourceRate.value) return '';
    const src = sourceCurrency.value;
    const pay = paymentCurrency.value;
    const books = booksCurrency.value;
    if (currenciesMatch(src, books) && !currenciesMatch(pay, books)) {
      return `Cash leaves the pot in ${src}. You record this pay-out in ${pay}. Enter the rate between them.`;
    }
    return `Cash is in ${src}. Payment is in ${pay}. Enter how much ${src} per 1 ${pay}.`;
  });

  const sourceToPaymentRateLabel = computed(
    () => `Rate (${sourceCurrency.value} per 1 ${paymentCurrency.value})`,
  );

  const paymentToBooksRateLabel = computed(
    () => `${booksCurrency.value} rate (per 1 ${paymentCurrency.value})`,
  );

  const syncDefaultPaymentToSourceRate = () => {
    if (!needsPaymentToSourceRate.value) {
      paymentToSourceRate.value = 1;
    } else if (paymentToSourceRate.value === 1) {
      paymentToSourceRate.value = null;
    }
  };

  const effectivePaymentToBooksRate = (
    overrideSourceRate?: number | null,
    overrideBooksRate?: number | null,
  ): number | null => {
    if (!needsPaymentToBooksFx.value) return null;
    const raw = needsSeparateBooksRate.value
      ? (overrideBooksRate ?? paymentToBooksRate.value)
      : (overrideSourceRate ?? paymentToSourceRate.value);
    return raw != null && Number.isFinite(Number(raw)) && Number(raw) > 0 ? Number(raw) : null;
  };

  return {
    paymentToBooksRate,
    paymentToSourceRate,
    needsPaymentToSourceRate,
    needsPaymentToBooksFx,
    needsSeparateBooksRate,
    needsAnyFx,
    sourceToPaymentHint,
    sourceToPaymentRateLabel,
    paymentToBooksRateLabel,
    syncDefaultPaymentToSourceRate,
    effectivePaymentToBooksRate,
    applyPrefilledRates,
  };
}
