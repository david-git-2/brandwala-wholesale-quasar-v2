import { computed, ref, watch, type ComputedRef, type Ref } from 'vue';
import type { CashbookLegPotChipOption } from './useCashbookLegPots';

export const BILL_PAY_BUNDLE_LINES_MAX = 25;

export type BillPayBundleLineDraft = {
  id: string;
  bundleId: number | null;
  amount: number | null;
};

export type BundleDebitPayload = { cash_bundle_id: number; amount: number };

function newLine(bundleId: number | null = null): BillPayBundleLineDraft {
  return {
    id: crypto.randomUUID(),
    bundleId,
    amount: null,
  };
}

function parseAmount(v: unknown): number | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export function useBillPayBundleLines(options: {
  enabled: Ref<boolean>;
  bundleOptions: ComputedRef<CashbookLegPotChipOption[]>;
  billDue: ComputedRef<number>;
  billCurrency: ComputedRef<string>;
  seedBundleId: ComputedRef<number | null>;
  seedAmount: ComputedRef<number | null>;
}) {
  const lines = ref<BillPayBundleLineDraft[]>([newLine()]);
  const submitAttempted = ref(false);

  const bundleById = computed(() => {
    const map = new Map<number, CashbookLegPotChipOption>();
    for (const o of options.bundleOptions.value) {
      map.set(o.value, o);
    }
    return map;
  });

  const usedBundleIds = computed(() => {
    const set = new Set<number>();
    for (const line of lines.value) {
      if (line.bundleId != null && line.bundleId > 0) set.add(line.bundleId);
    }
    return set;
  });

  const canAddLine = computed(
    () =>
      lines.value.length < BILL_PAY_BUNDLE_LINES_MAX
      && lines.value.length < options.bundleOptions.value.length,
  );

  const totalAmount = computed(() =>
    lines.value.reduce((sum, line) => {
      const amt = Number(line.amount);
      return sum + (Number.isFinite(amt) && amt > 0 ? amt : 0);
    }, 0),
  );

  function seedFromPrefill() {
    if (!options.enabled.value) return;
    const bundleId = options.seedBundleId.value;
    const amount = options.seedAmount.value;
  lines.value = [newLine(bundleId)];
    if (amount != null && amount > 0 && lines.value[0]) {
      lines.value[0].amount = amount;
    }
  }

  watch(
    () => [options.enabled.value, options.seedBundleId.value] as const,
    () => {
      if (!options.enabled.value) return;
      const hasAnyBundle = lines.value.some((l) => l.bundleId != null && l.bundleId > 0);
      if (!hasAnyBundle) seedFromPrefill();
    },
    { immediate: true },
  );

  const addLine = () => {
    if (!canAddLine.value) return;
    const sorted = [...options.bundleOptions.value].sort((a, b) => b.value - a.value);
    const next = sorted.find((o) => !usedBundleIds.value.has(o.value));
    lines.value.push(newLine(next?.value ?? null));
  };

  const removeLine = (id: string) => {
    if (lines.value.length <= 1) {
      lines.value = [newLine()];
      return;
    }
    lines.value = lines.value.filter((l) => l.id !== id);
  };

  const updateLine = (
    id: string,
    patch: Partial<Pick<BillPayBundleLineDraft, 'bundleId' | 'amount'>>,
  ) => {
    const idx = lines.value.findIndex((l) => l.id === id);
    if (idx < 0) return;
    const row = lines.value[idx];
    lines.value[idx] = { ...row, ...patch };
  };

  const lineAvailable = (bundleId: number | null): number | null => {
    if (bundleId == null || bundleId <= 0) return null;
    const opt = bundleById.value.get(bundleId);
    if (!opt) return null;
    return Number(opt.amount);
  };

  const showAmountError = (line: BillPayBundleLineDraft): boolean => {
    if (!submitAttempted.value) return false;
    const amt = Number(line.amount);
    if (!Number.isFinite(amt) || amt <= 0) return true;
    const avail = lineAvailable(line.bundleId);
    if (avail != null && amt > avail + 0.009) return true;
    return false;
  };

  const showBundleError = (line: BillPayBundleLineDraft): boolean =>
    submitAttempted.value && (line.bundleId == null || line.bundleId <= 0);

  const buildBundleDebits = (): BundleDebitPayload[] => {
    const out: BundleDebitPayload[] = [];
    for (const line of lines.value) {
      const bundleId = line.bundleId;
      const amt = Number(line.amount);
      if (bundleId == null || bundleId <= 0 || !Number.isFinite(amt) || amt <= 0) continue;
      out.push({ cash_bundle_id: bundleId, amount: Math.round(amt * 100) / 100 });
    }
    return out;
  };

  const submitDisabledReason = computed((): string | null => {
    const debits = buildBundleDebits();
    if (!debits.length) return 'Add at least one bundle with an amount greater than zero.';

    const due = options.billDue.value;
    const total = totalAmount.value;
    if (total <= 0) return 'Enter an amount greater than zero.';
    if (due > 0 && total > due + 0.009) {
      return 'Total cannot exceed bill due.';
    }

    const settle = options.billCurrency.value.trim().toUpperCase() || 'BDT';
    for (const line of lines.value) {
      const bundleId = line.bundleId;
      const amt = Number(line.amount);
      if (bundleId == null || bundleId <= 0) continue;
      if (!Number.isFinite(amt) || amt <= 0) continue;
      const opt = bundleById.value.get(bundleId);
      if (!opt) return 'Choose a valid bundle.';
      const ccy = opt.currencyCode?.trim().toUpperCase() || settle;
      if (ccy !== settle) {
        return 'All bundles must match the bill currency.';
      }
      const avail = Number(opt.amount);
      if (Number.isFinite(avail) && amt > avail + 0.009) {
        return 'One line exceeds bundle balance. Add money or lower the amount.';
      }
    }

    const ids = debits.map((d) => d.cash_bundle_id);
    if (new Set(ids).size !== ids.length) {
      return 'Each bundle can appear once.';
    }

    return null;
  });

  const primaryFromPotId = computed((): number | null => {
    const first = buildBundleDebits()[0];
    return first?.cash_bundle_id ?? null;
  });

  return {
    lines,
    submitAttempted,
    totalAmount,
    canAddLine,
    addLine,
    removeLine,
    updateLine,
    bundleById,
    usedBundleIds,
    lineAvailable,
    showAmountError,
    showBundleError,
    buildBundleDebits,
    submitDisabledReason,
    primaryFromPotId,
    parseAmount,
  };
}