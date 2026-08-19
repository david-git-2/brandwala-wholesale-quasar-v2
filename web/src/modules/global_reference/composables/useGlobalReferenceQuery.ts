import { useQuery } from '@tanstack/vue-query';
import { computed, type ComputedRef, type Ref } from 'vue';
import { globalReferenceRepository } from '../repositories/globalReferenceRepository';
import { globalReferenceQueryKeys } from '../shared/queryKeys/globalReferenceQueryKeys';

const STALE_TIME = 10 * 60 * 1000; // 10 minutes cache
const CURRENCY_STALE_TIME = 24 * 60 * 60 * 1000; // 24 hours cache for currencies

// --- Markets ---
export function useGlobalMarketsQuery() {
  return useQuery({
    queryKey: globalReferenceQueryKeys.markets(),
    queryFn: () => globalReferenceRepository.listMarkets(),
    staleTime: STALE_TIME,
  });
}

export function useMarketByIdQuery(id: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.marketDetail(id.value!)),
    queryFn: () => globalReferenceRepository.getMarketById(id.value!),
    enabled: computed(() => id.value !== null && id.value !== undefined && !isNaN(Number(id.value))),
    staleTime: STALE_TIME,
  });
}

export function useMarketByCodeQuery(code: Ref<string | null | undefined> | ComputedRef<string | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.marketByCode(code.value!)),
    queryFn: () => globalReferenceRepository.getMarketByCode(code.value!),
    enabled: computed(() => Boolean(code.value?.trim())),
    staleTime: STALE_TIME,
  });
}

// --- Currencies ---
export function useGlobalCurrenciesQuery() {
  return useQuery({
    queryKey: globalReferenceQueryKeys.currencies(),
    queryFn: () => globalReferenceRepository.listCurrencies(),
    staleTime: CURRENCY_STALE_TIME,
    gcTime: CURRENCY_STALE_TIME,
  });
}

export function useCurrencyByIdQuery(id: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.currencyDetail(id.value!)),
    queryFn: () => globalReferenceRepository.getCurrencyById(id.value!),
    enabled: computed(() => id.value !== null && id.value !== undefined && !isNaN(Number(id.value))),
    staleTime: STALE_TIME,
  });
}

export function useCurrencyByCodeQuery(code: Ref<string | null | undefined> | ComputedRef<string | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.currencyByCode(code.value!)),
    queryFn: () => globalReferenceRepository.getCurrencyByCode(code.value!),
    enabled: computed(() => Boolean(code.value?.trim())),
    staleTime: STALE_TIME,
  });
}

// --- Payment Methods ---
export function useGlobalPaymentMethodsQuery() {
  return useQuery({
    queryKey: globalReferenceQueryKeys.paymentMethods(),
    queryFn: () => globalReferenceRepository.listPaymentMethods(),
    staleTime: STALE_TIME,
  });
}

export function usePaymentMethodByIdQuery(id: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.paymentMethodDetail(id.value!)),
    queryFn: () => globalReferenceRepository.getPaymentMethodById(id.value!),
    enabled: computed(() => id.value !== null && id.value !== undefined && !isNaN(Number(id.value))),
    staleTime: STALE_TIME,
  });
}

// --- Units of Measure ---
export function useGlobalUnitsOfMeasureQuery() {
  return useQuery({
    queryKey: globalReferenceQueryKeys.unitsOfMeasure(),
    queryFn: () => globalReferenceRepository.listUnitsOfMeasure(),
    staleTime: STALE_TIME,
  });
}

export function useUnitOfMeasureByIdQuery(id: Ref<number | null | undefined> | ComputedRef<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => globalReferenceQueryKeys.unitOfMeasureDetail(id.value!)),
    queryFn: () => globalReferenceRepository.getUnitOfMeasureById(id.value!),
    enabled: computed(() => id.value !== null && id.value !== undefined && !isNaN(Number(id.value))),
    staleTime: STALE_TIME,
  });
}
