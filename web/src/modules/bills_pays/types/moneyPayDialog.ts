import type { OpenBillAllocRow } from '../composables/useOpenBillAllocations';
import type { CashbookLegPotChipOption } from '../composables/useCashbookLegPots';

export type MoneyPayKind = 'payment' | 'deposit' | 'withdrawal' | 'transfer';

export type MoneyPayAllocationLine = {
  bill_id: number;
  amount: number;
};

export type MoneyPayInstrumentFields = {
  bdBankId: number | null;
  chequeNumber: string;
  instrumentDate: string;
  instrumentReference: string;
};

export type MoneyPaySubmitPayload = {
  kind: MoneyPayKind;
  amount: number;
  paymentDate: string;
  fromPotId: number | null;
  toPotId: number | null;
  allocations: MoneyPayAllocationLine[];
  methodCode: string;
  reference: string | null;
  note: string | null;
  instrumentFields: MoneyPayInstrumentFields;
  /** Books / settlement FX (BDT per 1 bill currency when applicable). */
  exchangeRate?: number | null;
  /** Pot debit FX when pot currency ≠ bill currency. */
  transactionRate?: number | null;
  sourceCurrencyCode?: string | null;
};

/** Read-only header block for payment / pay modes */
export type MoneyPaySummaryContext = {
  modeCaption?: string;
  headline?: string;
  dueAmount?: number | null;
  dueCurrencyCode?: string | null;
  payerName?: string | null;
  payeeName?: string | null;
  booksPreviewLabel?: string | null;
};

export type MoneyPayDialogLegProps = {
  fromPartyName?: string;
  toPartyName?: string;
  fromPotOptions?: CashbookLegPotChipOption[];
  toPotOptions?: CashbookLegPotChipOption[];
  fromPotLoading?: boolean;
  toPotLoading?: boolean;
};

export type MoneyPayDialogFieldFlags = {
  showFromLeg?: boolean;
  showToLeg?: boolean;
  showAllocations?: boolean;
  showInstrument?: boolean;
  showDate?: boolean;
  showReferenceNote?: boolean;
};

export type MoneyPayDialogPrefill = {
  amount?: number | null;
  paymentDate?: string | null;
  methodCode?: string | null;
  fromPotId?: number | null;
  toPotId?: number | null;
  reference?: string | null;
  note?: string | null;
  allocationRows?: OpenBillAllocRow[];
};
