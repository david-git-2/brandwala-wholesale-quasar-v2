import { computed, ref, watch, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import type { CashbookPointRow } from '../repositories/cashbookRepository';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { formatAmountBdt } from 'src/utils/currency';
import type { BillPayCashbookLeg } from '../types/billPayCashbookLegs';

export type CashbookLegPotChipOption = {
  label: string;
  value: number;
  pointId: number;
  currencyCode: string;
  pointName: string;
  balanceDisplay: string;
};

type LegPotsQueryData = {
  accountId: number;
  defaultPotId: number | null;
  points: CashbookPointRow[];
  pots: Array<{
    id: number;
    cashbook_point_id: number;
    currency_code: string;
    amount: number;
  }>;
};

function mapBundledLeg(leg: BillPayCashbookLeg): LegPotsQueryData {
  const points: CashbookPointRow[] = leg.points.map((p) => ({
    id: p.id,
    cashbook_account_id: leg.cashbook_account_id,
    tenant_id: 0,
    code: p.code,
    name: p.name,
    is_active: p.is_active,
  }));
  return {
    accountId: leg.cashbook_account_id,
    defaultPotId: leg.default_pot_id,
    points,
    pots: leg.pots.map((pot) => ({
      id: pot.id,
      cashbook_point_id: pot.cashbook_point_id,
      currency_code: pot.currency_code,
      amount: pot.amount,
    })),
  };
}

function legFromBundle(
  bundledLeg: BillPayCashbookLeg | null | undefined,
  profileId: number | null | undefined,
  currency: string,
): LegPotsQueryData | null {
  if (bundledLeg == null || profileId == null || profileId <= 0) return null;
  if (bundledLeg.profile_id !== profileId) return null;
  const legCurrency = currency.trim().toUpperCase() || 'BDT';
  const hasCurrencyPot = bundledLeg.pots.some((p) => p.currency_code === legCurrency);
  if (!hasCurrencyPot && bundledLeg.pots.length > 0) {
    return null;
  }
  return mapBundledLeg(bundledLeg);
}

async function fetchLegPots(
  booksTenantId: number,
  profileId: number,
  currency: string,
): Promise<LegPotsQueryData> {
  const legCurrency = currency.trim().toUpperCase() || 'BDT';
  let accountId = 0;
  let defaultPotId: number | null = null;

  try {
    const provision = await moneyKernelRepository.provisionCashbookCurrency(
      booksTenantId,
      profileId,
      legCurrency,
    );
    accountId = Number(provision.cashbook_account_id) || 0;
    defaultPotId = Number(provision.pot_id) || null;
  } catch {
    /* view-only users rely on existing kernel pots */
  }

  const balances = await moneyKernelRepository.getPotBalances(
    booksTenantId,
    [profileId],
    null,
  );
  const rows = balances.rows ?? [];

  const pointById = new Map<number, CashbookPointRow>();
  const pots: LegPotsQueryData['pots'] = [];

  for (const row of rows) {
    const potId = Number(row.pot_id);
    if (!Number.isFinite(potId) || potId <= 0) continue;
    const detail = await moneyKernelRepository.getPotBalanceById(booksTenantId, potId);
    const pointId = Number(detail.cashbook_point_id);
    if (!Number.isFinite(pointId) || pointId <= 0) continue;
    if (!pointById.has(pointId)) {
      pointById.set(pointId, {
        id: pointId,
        cashbook_account_id: accountId,
        tenant_id: booksTenantId,
        code: 'main',
        name: 'Main',
        is_active: true,
      });
    }
    const cur = String(detail.currency_code ?? row.currency_code ?? 'BDT').trim().toUpperCase();
    pots.push({
      id: potId,
      cashbook_point_id: pointId,
      currency_code: cur,
      amount: Number(detail.amount ?? row.amount ?? 0),
    });
    if (cur === legCurrency) {
      defaultPotId = defaultPotId ?? potId;
    }
  }

  if (!accountId && pots.length === 0) {
    throw new Error(`No kernel cashbook pots for profile ${profileId}`);
  }

  return {
    accountId,
    defaultPotId,
    points: [...pointById.values()],
    pots,
  };
}

/** Points + pots for one money profile (chip labels include on-hand amount). */
export function useCashbookLegPots(
  profileId: Ref<number | null | undefined>,
  booksTenantId: Ref<number>,
  enabled: Ref<boolean>,
  preferredCurrencyCode?: Ref<string>,
  bundledLeg?: Ref<BillPayCashbookLeg | null | undefined>,
) {
  const selectedPotId = ref<number | null>(null);

  const legCurrency = computed(() => {
    const raw = preferredCurrencyCode?.value ?? 'BDT';
    return raw.trim().toUpperCase() || 'BDT';
  });

  const accountLookupEnabled = computed(
    () =>
      enabled.value &&
      booksTenantId.value > 0 &&
      profileId.value != null &&
      profileId.value > 0,
  );

  const legPotsQuery = useQuery({
    queryKey: computed(() =>
      [
        ...cashbookQueryKeys.root,
        'leg_pots',
        booksTenantId.value,
        profileId.value ?? 0,
        legCurrency.value,
        bundledLeg?.value?.pots?.length ?? -1,
      ] as const,
    ),
    queryFn: async (): Promise<LegPotsQueryData> => {
      const pid = profileId.value!;
      const fromBundle = legFromBundle(bundledLeg?.value, pid, legCurrency.value);
      if (fromBundle) return fromBundle;
      return fetchLegPots(booksTenantId.value, pid, legCurrency.value);
    },
    enabled: accountLookupEnabled,
    staleTime: 60_000,
  });

  const defaultPotId = computed(() => legPotsQuery.data.value?.defaultPotId ?? null);
  const activePoints = computed(() =>
    (legPotsQuery.data.value?.points ?? []).filter((p) => p.is_active),
  );

  const pointById = computed(() => {
    const map = new Map<number, CashbookPointRow>();
    for (const point of activePoints.value) {
      map.set(point.id, point);
    }
    return map;
  });

  const bundledPointNames = computed(() => {
    const leg = bundledLeg?.value;
    if (!leg || leg.profile_id !== profileId.value) return null;
    const map = new Map<number, string>();
    for (const pot of leg.pots) {
      if (pot.point_name) map.set(pot.cashbook_point_id, pot.point_name);
    }
    return map;
  });

  const chipOptions = computed((): CashbookLegPotChipOption[] => {
    const pots = legPotsQuery.data.value?.pots ?? [];
    return pots
      .map((pot) => {
        const point = pointById.value.get(pot.cashbook_point_id);
        const pointLabel =
          point?.name
          ?? bundledPointNames.value?.get(pot.cashbook_point_id)
          ?? 'Location';
        const cur = pot.currency_code.trim().toUpperCase();
        const balanceDisplay = `${cur} ${formatAmountBdt(pot.amount)}`;
        return {
          label: `${pointLabel} · ${balanceDisplay}`,
          value: pot.id,
          pointId: pot.cashbook_point_id,
          currencyCode: cur,
          pointName: pointLabel,
          balanceDisplay,
        };
      })
      .sort((a, b) => a.label.localeCompare(b.label));
  });

  const selectedPot = computed(() => {
    const id = selectedPotId.value;
    if (id == null) return null;
    return (legPotsQuery.data.value?.pots ?? []).find((p) => p.id === id) ?? null;
  });

  const cashbookPointId = computed(() => selectedPot.value?.cashbook_point_id ?? null);

  const sourceCurrencyCode = computed(
    () => selectedPot.value?.currency_code?.trim().toUpperCase() || 'BDT',
  );

  const syncDefaultPot = () => {
    const options = chipOptions.value;
    if (!options.length) {
      selectedPotId.value = null;
      return;
    }
    if (selectedPotId.value != null && options.some((o) => o.value === selectedPotId.value)) {
      return;
    }
    const serverDefault = defaultPotId.value;
    if (serverDefault != null && options.some((o) => o.value === serverDefault)) {
      selectedPotId.value = serverDefault;
      return;
    }
    const cur = legCurrency.value;
    const currencyMatch = options.find((o) => o.currencyCode === cur);
    const bdt = options.find((o) => o.currencyCode === 'BDT');
    selectedPotId.value = (currencyMatch ?? bdt ?? options[0]).value;
  };

  watch([chipOptions, profileId, defaultPotId, legCurrency], syncDefaultPot, { immediate: true });

  const loading = computed(() => {
    if (!accountLookupEnabled.value) return false;
    return legPotsQuery.isLoading.value;
  });

  return {
    selectedPotId,
    chipOptions,
    cashbookPointId,
    sourceCurrencyCode,
    loading,
  };
}
