import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { moneyKernelRepository } from 'src/modules/bills_pays/repositories/moneyKernelRepository';
import { cashbookQueryKeys } from 'src/modules/bills_pays/services/cashbookQueryKeys';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

export function profileCashbookBundlesQueryKey(
  booksTenantId: number,
  profileId: number,
): readonly [string, string, string, number, number] {
  return [...cashbookQueryKeys.root, 'profile_kernel_bundles', booksTenantId, profileId] as const;
}

function mapBundleRow(raw: {
  bundle_id?: number;
  cash_location_id?: number;
  location_code?: string;
  location_name?: string;
  desk_point_id?: number | null;
  currency_code?: string;
  amount?: number;
  books_rate?: number;
}): ProfileCashbookBundleRow | null {
  const bundleId = Number(raw.bundle_id);
  if (!Number.isFinite(bundleId) || bundleId <= 0) return null;
  return {
    bundleId,
    cashLocationId: Number(raw.cash_location_id ?? 0),
    locationCode: String(raw.location_code ?? '').trim(),
    locationName: String(raw.location_name ?? '').trim(),
    deskPointId:
      raw.desk_point_id == null || raw.desk_point_id === undefined
        ? null
        : Number(raw.desk_point_id),
    currencyCode: String(raw.currency_code ?? 'BDT').trim().toUpperCase(),
    amount: Number(raw.amount ?? 0),
    booksRate: Number(raw.books_rate ?? 1),
  };
}

export function useProfileCashbookBundlesQuery(
  booksTenantId: Ref<number>,
  profileId: Ref<number | null>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() =>
      profileCashbookBundlesQueryKey(booksTenantId.value, profileId.value ?? 0),
    ),
    queryFn: async () => {
      const pid = profileId.value;
      if (pid == null) throw new Error('Profile not set.');
      const payload = await moneyKernelRepository.listProfileCashbookBundles(
        booksTenantId.value,
        pid,
      );
      const rows = payload.bundles ?? [];
      return rows
        .map((row) => mapBundleRow(row))
        .filter((row): row is ProfileCashbookBundleRow => row != null);
    },
    enabled: computed(() => enabled.value && booksTenantId.value > 0 && profileId.value != null),
    staleTime: 30_000,
  });
}
