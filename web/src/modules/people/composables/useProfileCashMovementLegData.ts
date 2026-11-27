import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import type { CashbookPointRow } from 'src/modules/finance/submodules/bills_pays/repositories/cashbookRepository';
import { useMoneyKernelCurrenciesQuery } from 'src/modules/finance/submodules/bills_pays/composables/useMoneyKernelCurrenciesQuery';
import { useProfileCashbookBundlesQuery } from './useProfileCashbookBundlesQuery';
import { cashbookQueryKeys } from 'src/modules/finance/submodules/bills_pays/services/cashbookQueryKeys';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

function bundleMatchesLocation(
  bundle: ProfileCashbookBundleRow,
  locationId: number,
  legacyPoint?: CashbookPointRow | null,
): boolean {
  if (bundle.cashLocationId === locationId) return true;
  if (legacyPoint && bundle.deskPointId != null && bundle.deskPointId === legacyPoint.id) {
    return true;
  }
  if (legacyPoint) {
    const code = legacyPoint.code?.trim().toLowerCase() ?? '';
    return code.length > 0 && bundle.locationCode.toLowerCase() === code;
  }
  return false;
}

type KernelLocationRow = { id: number; code: string; name: string; is_active: boolean };

function parseKernelLocations(payload: unknown): KernelLocationRow[] {
  if (!payload || typeof payload !== 'object') return [];
  const points = (payload as { points?: unknown }).points;
  if (!Array.isArray(points)) return [];
  const rows: KernelLocationRow[] = [];
  for (const raw of points) {
    if (!raw || typeof raw !== 'object') continue;
    const id = Number((raw as { id?: unknown }).id);
    if (!Number.isFinite(id) || id <= 0) continue;
    rows.push({
      id,
      code: String((raw as { code?: unknown }).code ?? '').trim(),
      name: String((raw as { name?: unknown }).name ?? '').trim(),
      is_active: (raw as { is_active?: unknown }).is_active !== false,
    });
  }
  return rows.filter((r) => r.is_active).sort((a, b) => a.name.localeCompare(b.name));
}

export function useProfileCashMovementLegData(
  booksTenantId: Ref<number>,
  profileId: Ref<number | null>,
  enabled: Ref<boolean>,
) {
  const bundlesQuery = useProfileCashbookBundlesQuery(booksTenantId, profileId, enabled);

  const kernelLocationsQuery = useQuery({
    queryKey: computed(() =>
      [
        ...cashbookQueryKeys.root,
        'kernel_cash_locations',
        booksTenantId.value,
        profileId.value,
      ] as const,
    ),
    queryFn: async () => {
      const pid = profileId.value;
      if (pid == null) throw new Error('Profile not set.');
      const { data, error } = await supabase.rpc('_desk_profile_cashbook_leg_json', {
        p_books_tenant_id: booksTenantId.value,
        p_bill_profile_id: pid,
        p_currency_code: 'BDT',
      });
      if (error) throw error;
      return parseKernelLocations(data);
    },
    enabled: computed(
      () => enabled.value && booksTenantId.value > 0 && profileId.value != null,
    ),
    staleTime: 30_000,
  });

  const { data: moneyCurrencies } = useMoneyKernelCurrenciesQuery();

  const kernelLocations = computed(() => kernelLocationsQuery.data.value ?? []);

  const points = computed((): CashbookPointRow[] =>
    kernelLocations.value.map((loc) => ({
      id: loc.id,
      cashbook_account_id: 0,
      tenant_id: booksTenantId.value,
      code: loc.code,
      name: loc.name || loc.code || 'Location',
      is_active: true,
    })),
  );

  const bundles = computed(() => bundlesQuery.data.value ?? []);

  const loading = computed(
    () =>
      kernelLocationsQuery.isPending.value
      || kernelLocationsQuery.isFetching.value
      || bundlesQuery.isPending.value
      || bundlesQuery.isFetching.value,
  );

  const loadError = computed(() => {
    const err = kernelLocationsQuery.error.value ?? bundlesQuery.error.value;
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
    kernelLocations.value.map((loc) => ({
      label: loc.name?.trim() || loc.code || 'Location',
      value: loc.id,
    })),
  );

  function bundlesForPointAndCurrency(
    locationId: number | null,
    currencyCode: string,
  ): ProfileCashbookBundleRow[] {
    if (locationId == null || !currencyCode.trim()) return [];
    const legacyPoint = points.value.find((p) => p.id === locationId) ?? null;
    const ccy = currencyCode.trim().toUpperCase();
    return bundles.value.filter(
      (b) => b.currencyCode === ccy && bundleMatchesLocation(b, locationId, legacyPoint),
    );
  }

  function pointById(locationId: number | null): CashbookPointRow | null {
    if (locationId == null) return null;
    return points.value.find((p) => p.id === locationId) ?? null;
  }

  const refetch = async () => {
    await Promise.all([kernelLocationsQuery.refetch(), bundlesQuery.refetch()]);
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
    cashbookAccountId: computed(() => null),
  };
}