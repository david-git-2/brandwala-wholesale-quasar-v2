import type { PayListRow } from '../repositories/paysRepository';
import {
  formatAmountBdt,
  formatBdtTaka,
  formatSettlementCurrencyAmount,
  SETTLEMENT_CURRENCY_SYMBOL,
} from 'src/utils/currency';

export type PayAmountDisplayMode = 'bdt' | 'original';

export function payCurrencySymbol(
  currencyCode: string,
  symbolMap?: Map<string, string>,
): string {
  const code = (currencyCode || 'BDT').trim().toUpperCase();
  const fromMap = symbolMap?.get(code)?.trim();
  if (fromMap) return fromMap;
  return SETTLEMENT_CURRENCY_SYMBOL[code] ?? code;
}

function payRowBdtValue(row: PayListRow): number {
  if (!payListIsFx(row)) return row.amount;
  const foreign = row.foreign_amount;
  const rate = Number(row.exchange_rate) || 0;
  if (foreign != null && Number.isFinite(foreign) && foreign > 0 && rate > 0) {
    return Math.round(foreign * rate * 10_000) / 10_000;
  }
  return row.amount;
}

function payRowOriginalAmount(row: PayListRow): { value: number; currencyCode: string } {
  const code = (row.settlement_currency_code || 'BDT').trim().toUpperCase();
  if (payListIsFx(row)) {
    const foreign = row.foreign_amount;
    if (foreign != null && Number.isFinite(foreign) && foreign > 0) {
      return { value: foreign, currencyCode: code };
    }
  }
  return { value: row.amount, currencyCode: 'BDT' };
}

export function payRowDisplayAmount(
  row: PayListRow,
  mode: PayAmountDisplayMode,
): { value: number; currencyCode: string } {
  if (mode === 'bdt') {
    return { value: payRowBdtValue(row), currencyCode: 'BDT' };
  }
  return payRowOriginalAmount(row);
}

export function payRowAmountLabel(
  row: PayListRow,
  mode: PayAmountDisplayMode,
  symbolMap?: Map<string, string>,
): string {
  const { value, currencyCode } = payRowDisplayAmount(row, mode);
  return formatSettlementCurrencyAmount(
    value,
    currencyCode,
    payCurrencySymbol(currencyCode, symbolMap),
  );
}

export function paySignedAmountParts(
  row: PayListRow,
  viewedProfileId: number | null | undefined,
  mode: PayAmountDisplayMode = 'original',
  symbolMap?: Map<string, string>,
): { sign: string; symbol: string; amount: string } {
  const { value, currencyCode } = payRowDisplayAmount(row, mode);
  const symbol = payCurrencySymbol(currencyCode, symbolMap);
  const amount = formatAmountBdt(value);
  const sign = payIsInflowForProfile(row, viewedProfileId) ? '+' : '−';
  return { sign, symbol, amount };
}

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

const EXTERNAL_ENDPOINT = 'External';

export function payEndpointLabel(
  profileId: number | null | undefined,
  profileName: string | null | undefined,
  viewedProfileId: number | null | undefined,
  viewedProfileDisplayName: string | null | undefined,
): string {
  if (
    profileId != null
    && viewedProfileId != null
    && profileId === viewedProfileId
    && viewedProfileDisplayName?.trim()
  ) {
    return viewedProfileDisplayName.trim();
  }
  const name = profileName?.trim();
  if (name) return name;
  if (profileId == null) return EXTERNAL_ENDPOINT;
  return '—';
}

export function payIsInflowForProfile(
  row: PayListRow,
  viewedProfileId: number | null | undefined,
): boolean {
  if (viewedProfileId != null && viewedProfileId > 0) {
    if (row.to_profile_id === viewedProfileId) return true;
    if (row.from_profile_id === viewedProfileId) return false;
  }
  return row.direction === 'in';
}

export function payFromToLine(
  row: PayListRow,
  viewedProfileId: number | null | undefined,
  viewedProfileDisplayName: string,
): string {
  const from = payEndpointLabel(
    row.from_profile_id,
    row.from_profile_name,
    viewedProfileId,
    viewedProfileDisplayName,
  );
  const to = payEndpointLabel(
    row.to_profile_id,
    row.to_profile_name,
    viewedProfileId,
    viewedProfileDisplayName,
  );
  return `${from} → ${to}`;
}

export function paySignedAmountLabel(
  row: PayListRow,
  viewedProfileId: number | null | undefined,
  mode: PayAmountDisplayMode = 'original',
  symbolMap?: Map<string, string>,
): string {
  const { sign, symbol, amount } = paySignedAmountParts(row, viewedProfileId, mode, symbolMap);
  return `${sign}${symbol}${amount}`;
}

export function payTransactionSourceLabel(source: string): string {
  if (source === 'kernel_deposit') return 'Deposit';
  if (source === 'kernel_withdrawal') return 'Withdrawal';
  if (source === 'kernel_transfer') return 'Transfer';
  if (source === 'kernel_payment') return 'Payment';
  if (source === 'ap_payout') return 'AP pay out';
  if (source === 'courier_remittance') return 'Remittance';
  if (source === 'store_credit') return 'Store credit';
  if (source === 'bank') return 'Bank';
  return 'Pay in';
}

const KERNEL_REVERT_KINDS = new Set(['deposit', 'withdrawal', 'transfer']);

export function payProfileKernelCanRevert(row: PayListRow): boolean {
  if (row.spine !== 'kernel') return false;
  if (row.reverted_at) return false;
  if (row.is_reversal) return false;
  const kind = row.kernel_kind ?? row.source.replace(/^kernel_/, '');
  return KERNEL_REVERT_KINDS.has(kind);
}

function payListFxMetaHint(
  row: PayListRow,
  mode: PayAmountDisplayMode,
  symbolMap?: Map<string, string>,
): string | null {
  if (!payListIsFx(row)) return null;
  if (mode === 'bdt') {
    const { value, currencyCode } = payRowOriginalAmount(row);
    return formatSettlementCurrencyAmount(
      value,
      currencyCode,
      payCurrencySymbol(currencyCode, symbolMap),
    );
  }
  return payListFxSubline(row);
}

export function payTransactionMetaParts(
  row: PayListRow,
  mode: PayAmountDisplayMode = 'original',
  symbolMap?: Map<string, string>,
): string[] {
  const parts: string[] = [];
  if (row.reverted_at) {
    const why = row.revert_reason?.trim();
    parts.push(why ? `Reverted · ${why}` : 'Reverted');
  } else if (row.is_reversal) {
    parts.push('Reversal');
  }
  const src = payTransactionSourceLabel(row.source);
  if (src) parts.push(src);
  if (row.payment_date) parts.push(row.payment_date);
  if (row.related_invoice_no?.trim()) parts.push(row.related_invoice_no.trim());
  if (row.reference?.trim()) parts.push(row.reference.trim());
  if (row.description?.trim()) parts.push(row.description.trim());
  if (row.note?.trim()) parts.push(row.note.trim());
  const fx = payListFxMetaHint(row, mode, symbolMap);
  if (fx) parts.push(fx);
  if (row.unallocated_amount > 0) {
    parts.push(`+${formatBdtTaka(row.unallocated_amount)} leftover`);
  }
  return parts;
}

export function payTransactionMetaLine(
  row: PayListRow,
  mode: PayAmountDisplayMode = 'original',
  symbolMap?: Map<string, string>,
): string {
  return payTransactionMetaParts(row, mode, symbolMap).join(' · ');
}
