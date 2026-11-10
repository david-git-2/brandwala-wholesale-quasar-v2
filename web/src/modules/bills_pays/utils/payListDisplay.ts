import type { PayListRow } from '../repositories/paysRepository';
import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';

export function payListIsFx(row: PayListRow): boolean {
  const code = (row.settlement_currency_code || 'BDT').trim().toUpperCase();
  if (code !== 'BDT') return true;
  const rate = Number(row.exchange_rate) || 0;
  return rate > 0 && Math.abs(rate - 1) > 0.0001;
}

export function payListPrimaryAmountLabel(row: PayListRow): string {
  if (payListIsFx(row)) {
    const foreign = row.foreign_amount;
    if (foreign != null && Number.isFinite(foreign) && foreign > 0) {
      return formatSettlementCurrencyAmount(foreign, row.settlement_currency_code);
    }
  }
  return formatBdtTaka(row.amount);
}

export function payListFxSubline(row: PayListRow): string | null {
  if (!payListIsFx(row)) return null;
  const code = (row.settlement_currency_code || 'BDT').trim().toUpperCase();
  const rate = Number(row.exchange_rate) || 1;
  return `${formatBdtTaka(row.amount)} @ ${rate} BDT/${code}`;
}

export function payListDirectionHeadline(
  row: PayListRow,
  perspective: 'tenant' | 'party',
): string {
  const dirIn = row.direction === 'in';
  const counterparty = row.counterparty_name?.trim() || row.profile_name?.trim();
  if (perspective === 'tenant') {
    if (dirIn) {
      return counterparty ? `Received · ${counterparty}` : 'Received';
    }
    return counterparty ? `Paid out · ${counterparty}` : 'Paid out';
  }
  if (dirIn) {
    return 'Received';
  }
  return 'Paid out';
}

export function payListMetaPartyLabel(
  row: PayListRow,
  perspective: 'tenant' | 'party',
): string {
  if (perspective === 'tenant') {
    return row.counterparty_name?.trim() || row.profile_name?.trim() || '—';
  }
  return row.profile_name?.trim() || '—';
}
