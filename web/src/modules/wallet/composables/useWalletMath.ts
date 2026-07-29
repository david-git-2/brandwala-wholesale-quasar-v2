import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import type { UniversalWalletLedgerEntry } from '../types';

export interface WalletTotals {
  currentBalance: number;
  totalCredits: number;
  totalDebits: number;
  netFlow: number;
  entryCount: number;
  /** Section-level aggregates: net amount per metadata.section (credits positive, debits negative) */
  sectionTotals: Record<string, number>;
}

/**
 * Calculates current balance, total credits, total debits, and net flow from a list of ledger entries.
 */
export function calculateWalletTotals(entries: UniversalWalletLedgerEntry[]): WalletTotals {
  if (!entries || entries.length === 0) {
    return {
      currentBalance: 0,
      totalCredits: 0,
      totalDebits: 0,
      netFlow: 0,
      entryCount: 0,
      sectionTotals: {},
    };
  }

  // entries are sorted created_at desc, so the first entry holds the latest running balance
  const currentBalance = Number(entries[0]?.balance_after ?? 0);

  let totalCredits = 0;
  let totalDebits = 0;
  const sectionTotals: Record<string, number> = {};

  for (const entry of entries) {
    const baseAmt = Number(entry.base_amount || 0);
    if (entry.type === 'credit') {
      totalCredits += baseAmt;
    } else if (entry.type === 'debit') {
      totalDebits += baseAmt;
    }
    const section: string = entry.metadata?.section ?? 'other';
    const signed = entry.type === 'credit' ? baseAmt : -baseAmt;
    sectionTotals[section] = (sectionTotals[section] ?? 0) + signed;
  }

  const netFlow = totalCredits - totalDebits;

  return {
    currentBalance,
    totalCredits,
    totalDebits,
    netFlow,
    entryCount: entries.length,
    sectionTotals,
  };
}

/**
 * Reactive composable wrapper around calculateWalletTotals.
 */
export function useWalletMath(entriesInput: MaybeRefOrGetter<UniversalWalletLedgerEntry[]>) {
  const totals = computed(() => {
    const entries = toValue(entriesInput) || [];
    return calculateWalletTotals(entries);
  });

  return {
    totals,
    currentBalance: computed(() => totals.value.currentBalance),
    totalCredits: computed(() => totals.value.totalCredits),
    totalDebits: computed(() => totals.value.totalDebits),
    netFlow: computed(() => totals.value.netFlow),
    entryCount: computed(() => totals.value.entryCount),
  };
}
