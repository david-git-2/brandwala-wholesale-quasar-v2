import { computed, ref, watch, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import type { CashbookPointRow } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { formatAmountBdt } from 'src/utils/currency';
import type { BillPayCashbookLeg } from '../types/billPayCashbookLegs';

export type CashbookLegPotChipOption = {
  label: string;
  value: number;
  pointId: number;
  currencyCode: string;
  pointName: string;
  balanceDisplay: string;
  amount: number;
  booksRate: number | null;
  drawerGroup: string | null;
};

export type CashbookLegLocationSection = {
  pointId: number;
  pointName: string;
  pots: CashbookLegPotChipOption[];
};

type LegPotRow = {
  id: number;
  cashbook_point_id: number;
  currency_code: string;
  amount: number;
  books_rate: number | null;
  drawer_group: string | null;
};

type LegPotsQueryData = {
  accountId: number;
  defaultPotId: number | null;
  points: CashbookPointRow[];
  pots: LegPotRow[];
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
      books_rate: pot.books_rate,
      drawer_group: pot.drawer_group,
    })),
  };
}

async function fetchKernelProfilePots(
  booksTenantId: number,
  profileId: number,
): Promise<LegPotsQueryData> {
  try {
    await moneyKernelRepository.provisionCashbookCurrency(booksTenantId, profileId, 'BDT');
  } catch {
    /* view-only */
  }
  const balances = await moneyKernelRepository.getPotBalances(booksTenantId, [profileId], null);
  const rows = balances.rows ?? [];
  const mainPointId = 1;
  const pots: LegPotRow[] = rows
    .map((row) => {
      const potId = Number(row.pot_id);
      if (!Number.isFinite(potId) || potId <= 0) return null;
      return {
        id: potId,
        cashbook_point_id: mainPointId,
        currency_code: String(row.currency_code ?? 'BDT').trim().toUpperCase(),
        amount: Number(row.amount ?? 0),
        books_rate: null,
        drawer_group: null,
      };
    })
    .filter((p): p is LegPotRow => p != null);

  return {
    accountId: 0,
    defaultPotId: pots[0]?.id ?? null,
    points: [
      {
        id: mainPointId,
        cashbook_account_id: 0,
        tenant_id: booksTenantId,
        code: 'main',
        name: 'Main',
        is_active: true,
      },
    ],
    pots,
  };
}

function legFromBundle(
  bundledLeg: BillPayCashbookLeg | null | undefined,
  profileId: number | null | undefined,
): LegPotsQueryData | null {
  if (bundledLeg == null || profileId == null || profileId <= 0) return null;
  if (bundledLeg.profile_id !== profileId) return null;
  if (!bundledLeg.pots.length && !bundledLeg.points.length) return null;
  return mapBundledLeg(bundledLeg);
}

/** Points + pots for one money profile (chip labels include on-hand amount). */
export function useCashbookLegPots(
  profileId: Ref<number | null | undefined>,
  booksTenantId: Ref<number>,
  enabled: Ref<boolean>,
  preferredCurrencyCode?: Ref<string>,
  bundledLeg?: Ref<BillPayCashbookLeg | null | undefined>,
  /** When no bill bundle leg, load pots from kernel (e.g. People deposit/withdraw). */
  kernelFetchWhenEmpty?: Ref<boolean>,
  /** Paying leg: only bundles with on-hand balance in the bill currency. */
  positiveBalanceOnly?: Ref<boolean>,
) {
  const selectedPotId = ref<number | null>(null);
  const pendingSelectPotId = ref<number | null>(null);

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

  const bundledLegData = computed(() =>
    legFromBundle(bundledLeg?.value, profileId.value ?? null),
  );

  const kernelLegPotsEnabled = computed(
    () =>
      accountLookupEnabled.value
      && bundledLegData.value == null
      && kernelFetchWhenEmpty?.value === true,
  );

  const kernelLegPotsQuery = useQuery({
    queryKey: computed(() =>
      [
        ...cashbookQueryKeys.root,
        'leg_pots',
        booksTenantId.value,
        profileId.value ?? 0,
        legCurrency.value,
      ] as const,
    ),
    queryFn: async (): Promise<LegPotsQueryData> =>
      fetchKernelProfilePots(booksTenantId.value, profileId.value!),
    enabled: kernelLegPotsEnabled,
    staleTime: 60_000,
  });

  const emptyLegPots = computed((): LegPotsQueryData => ({
    accountId: bundledLeg?.value?.cashbook_account_id ?? 0,
    defaultPotId: null,
    points: [],
    pots: [],
  }));

  /** Bill bundle legs stay live in the parent cache (e.g. after Add money deposit). */
  const legPotsData = computed((): LegPotsQueryData => {
    if (bundledLegData.value) return bundledLegData.value;
    if (kernelFetchWhenEmpty?.value) {
      return kernelLegPotsQuery.data.value ?? emptyLegPots.value;
    }
    return emptyLegPots.value;
  });

  const defaultPotId = computed(() => legPotsData.value.defaultPotId ?? null);
  const activePoints = computed(() =>
    (legPotsData.value.points ?? []).filter((p) => p.is_active),
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
    for (const point of leg.points) {
      map.set(point.id, point.name);
    }
    return map;
  });

  const chipOptions = computed((): CashbookLegPotChipOption[] => {
    const pots = legPotsData.value.pots ?? [];
    const requireFunds = positiveBalanceOnly?.value === true;
    return pots
      .filter((pot) => {
        const cur = pot.currency_code.trim().toUpperCase();
        if (cur !== legCurrency.value) return false;
        if (requireFunds && !(Number(pot.amount) > 0.009)) return false;
        return true;
      })
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
          amount: pot.amount,
          booksRate: pot.books_rate,
          drawerGroup: pot.drawer_group,
        };
      })
      .sort((a, b) => a.label.localeCompare(b.label));
  });

  const locationSections = computed((): CashbookLegLocationSection[] => {
    const sectionMap = new Map<number, CashbookLegLocationSection>();
    for (const opt of chipOptions.value) {
      let section = sectionMap.get(opt.pointId);
      if (!section) {
        section = { pointId: opt.pointId, pointName: opt.pointName, pots: [] };
        sectionMap.set(opt.pointId, section);
      }
      section.pots.push(opt);
    }
    return [...sectionMap.values()].sort((a, b) => a.pointName.localeCompare(b.pointName));
  });

  const selectedPot = computed(() => {
    const id = selectedPotId.value;
    if (id == null) return null;
    return (legPotsData.value.pots ?? []).find((p) => p.id === id) ?? null;
  });

  const cashbookPointId = computed(() => selectedPot.value?.cashbook_point_id ?? null);

  const sourceCurrencyCode = computed(
    () => selectedPot.value?.currency_code?.trim().toUpperCase() || 'BDT',
  );

  const syncDefaultPot = () => {
    const pending = pendingSelectPotId.value;
    if (pending != null) {
      const options = chipOptions.value;
      if (options.some((o) => o.value === pending)) {
        selectedPotId.value = pending;
        pendingSelectPotId.value = null;
        return;
      }
    }

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

  const selectPotAfterRefresh = (potId: number) => {
    pendingSelectPotId.value = potId;
    syncDefaultPot();
  };

  const loading = computed(() => {
    if (!accountLookupEnabled.value) return false;
    if (bundledLegData.value) return false;
    return kernelLegPotsQuery.isLoading.value;
  });

  const selectedPotBalance = computed(() => selectedPot.value?.amount ?? null);

  return {
    selectedPotId,
    chipOptions,
    locationSections,
    cashbookPointId,
    sourceCurrencyCode,
    selectedPotBalance,
    selectPotAfterRefresh,
    loading,
  };
}
