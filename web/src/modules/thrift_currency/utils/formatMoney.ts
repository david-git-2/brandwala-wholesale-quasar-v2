import type { ThriftCurrency } from '../types';

export function formatThriftAmount(
  amount: number | null | undefined,
  currency?: ThriftCurrency | null,
): string {
  if (amount == null || Number.isNaN(Number(amount))) return '—';
  const symbol = currency?.symbol ?? '';
  return `${symbol}${Number(amount).toFixed(2)}`;
}
