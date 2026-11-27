/** Captured before reverse_pay — starting values for re-post only. */
export type PayCorrectionSnapshot = {
  paymentId: number;
  paymentDate: string;
  source: string;
  method: string | null;
  settlementCurrencyCode: string;
  foreignAmount: number | null;
  exchangeRate: number;
  transactionRate: number | null;
  sourceCurrencyCode: string | null;
  cashbookPointPotId: number | null;
  amountBdt: number;
  reference: string | null;
  instrumentMethodCode: string | null;
};
