import { computed, type Ref } from 'vue';
import type { CashbookPointRow } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { useMoneyKernelCurrenciesQuery } from 'src/modules/bills_pays/composables/useMoneyKernelCurrenciesQuery';
import { useCashbookPointsForProfileQuery } from './useCashbookPointsForProfileQuery';
import { useProfileCashbookBundlesQuery } from './useProfileCashbookBundlesQuery';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

function bundleMatchesPoint(bundle: ProfileCashbookBundleRow, point: CashbookPointRow): boolean {
  if (bundle.deskPointId != null && bundle.deskPointId === point.id) return true;
  const code = point.code?.trim().toLowerCase() ?? '';
  return code.length > 0 && bundle.locationCode.toLowerCase() === code;
}

export function useProfileCashMovementLegData(
  booksTenantId: Ref<number>,
  profileId: Ref<number | null>,
  enabled: Ref<boolean>,
) {
  const { pointsQuery, cashbookAccountId } = useCashbookPointsForProfileQuery(
    booksTenantId,
    profileId,
    enabled,
  );

  const bundlesQuery = useProfileCashbookBundlesQuery(booksTenantId, profileId, enabled);

  const { data: moneyCurrencies } = useMoneyKernelCurrenciesQuery();

  const points = computed((): CashbookPointRow[] => {
    const list = pointsQuery.data.value ?? [];
    return [...list]
      .filter((p) => p.is_active !== false)
      .sort((a, b) => a.name.localeCompare(b.name));
  });

  const bundles = computed(() => bundlesQuery.data.value ?? []);

  const loading = computed(
    () =>
      pointsQuery.isPending.value
      || pointsQuery.isFetching.value
      || bundlesQuery.isPending.value
      || bundlesQuery.isFetching.value,
  );

  const loadError = computed(() => {
    const err = pointsQuery.error.value ?? bundlesQuery.error.value;
    return err instanceof Error ? err.message : null;
  });

  const currencyOptions = computed(() => {
    const codes = new Set<string>();
    for (const c of moneyCurrencies.value ?? []) {
      const code = c.code?.trim().toUpperCase();
      if (code) codes.add(code);
    }
    for (const b of bundles.value) {
      codes.add(b.currencyCode);
    }
    if (!codes.size) codes.add('BDT');
    const sorted = [...codes].sort((a, b) => {
      if (a === 'BDT') return -1;
      if (b === 'BDT') return 1;
      return a.localeCompare(b);
    });
    return sorted.map((code) => {
      const meta = moneyCurrencies.value?.find((c) => c.code.toUpperCase() === code);
      const symbol = meta?.symbol?.trim();
      return {
        label: symbol && symbol !== code ? `${code} (${symbol})` : code,
        value: code,
      };
    });
  });

  const locationOptions = computed(() =>
    points.value.map((p) => ({
      label: p.name?.trim() || p.code || 'Location',
      value: p.id,
    })),
  );

  function bundlesForPointAndCurrency(
    pointId: number | null,
    currencyCode: string,
  ): ProfileCashbookBundleRow[] {
    if (pointId == null || !currencyCode.trim()) return [];
    const point = points.value.find((p) => p.id === pointId);
    if (!point) return [];
    const ccy = currencyCode.trim().toUpperCase();
    return bundles.value.filter(
      (b) => b.currencyCode === ccy && bundleMatchesPoint(b, point),
    );
  }

  function pointById(pointId: number | null): CashbookPointRow | null {
    if (pointId == null) return null;
    return points.value.find((p) => p.id === pointId) ?? null;
  }

  const refetch = async () => {
    await Promise.all([pointsQuery.refetch(), bundlesQuery.refetch()]);
  };

  return {
    points,
    bundles,
    loading,
    loadError,
    currencyOptions,
    locationOptions,
    bundlesForPointAndCurrency,
    pointById,
    refetch,
    cashbookAccountId,
  };
}
