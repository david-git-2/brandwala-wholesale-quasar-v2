import type { OpenBillAllocRow } from '../composables/useOpenBillAllocations';
import type {
  CashbookLegLocationSection,
  CashbookLegPotChipOption,
} from '../composables/useCashbookLegPots';

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

/** One deposit row when posting several `rpc_deposit` calls from a single profile dialog. */
export type MoneyPayDepositLine = {
  amount: number;
  methodCode: string;
  reference?: string | null;
  note?: string | null;
  instrumentFields: MoneyPayInstrumentFields;
  /** Overrides dialog payment date when set. */
  paymentDate?: string | null;
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
  /** Selected leg currency (profile cash deposit / withdraw). */
  legCurrencyCode?: string | null;
  /** Desk point id for profile deposit / withdraw. */
  legLocationPointId?: number | null;
  /** Desk location name for prefill before profile points query loads. */
  legLocationPointLabel?: string | null;
  /** Cash location code (desk point `code`) when depositing without explicit bundle id. */
  legLocationCode?: string | null;
  /** Books rate (BDT per 1 unit) when opening a new FX tranche on deposit. */
  legBooksRate?: number | null;
  /**
   * Profile multi-line deposit: one `rpc_deposit` per line; shared leg fields on the payload root.
   * When length ≥ 1, root `amount` / `methodCode` are not used for posting.
   */
  depositLines?: MoneyPayDepositLine[];
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
  fromPotSections?: CashbookLegLocationSection[];
  toPotSections?: CashbookLegLocationSection[];
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
  /** AR dual cashbook: deposit to open/select tenant receive bundle */
  showCreateToBundle?: boolean;
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
  /** Profile cash deposit / withdraw — lock currency picker when set. */
  currencyCode?: string | null;
  legLocationPointId?: number | null;
  legLocationPointLabel?: string | null;
};
