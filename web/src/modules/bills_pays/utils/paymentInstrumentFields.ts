import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';

export type PaymentMethodFieldMeta = {
  code: string;
  category: string;
};

export const normalizePaymentMethodCode = (code: string) => code.trim().toLowerCase();

export const paymentMethodFieldFlags = (meta: PaymentMethodFieldMeta | null) => {
  const code = meta?.code?.toUpperCase() ?? '';
  const category = meta?.category ?? '';
  const isCheque = code === 'CHEQUE';
  const isBankTransfer = code === 'BANK_TRANSFER';
  return {
    showBank: isCheque || isBankTransfer,
    showChequeNumber: isCheque,
    showInstrumentDate: isCheque || isBankTransfer,
    showInstrumentReference:
      category === 'bd_mobile_wallet' ||
      category === 'card' ||
      category === 'international' ||
      isBankTransfer ||
      isCheque,
    bankRequired: isCheque,
    chequeNumberRequired: isCheque,
    instrumentDateRequired: isCheque,
    bankOrReferenceRequired: isBankTransfer,
    bankLabel: isCheque ? 'Bank' : 'Bank (optional)',
    instrumentReferenceLabel:
      category === 'bd_mobile_wallet'
        ? 'Trx ID (optional)'
        : isBankTransfer
          ? 'Bank trx reference (optional)'
          : isCheque
            ? 'Memo (optional)'
            : 'Transaction reference (optional)',
    instrumentDateLabel: isCheque ? 'Cheque date' : 'Transfer date (optional)',
  };
};

export const paymentInstrumentExtrasBlockReason = (
  flags: ReturnType<typeof paymentMethodFieldFlags>,
  fields: {
    bdBankId: number | null;
    chequeNumber: string;
    instrumentDate: string;
    instrumentReference: string;
  },
): string | null => {
  const missing: string[] = [];
  if (flags.bankRequired && fields.bdBankId == null) missing.push('bank');
  if (flags.chequeNumberRequired && !fields.chequeNumber.trim()) missing.push('cheque number');
  if (flags.instrumentDateRequired && !fields.instrumentDate.trim()) missing.push('cheque date');
  if (missing.length) return `Fill in: ${missing.join(', ')}`;
  if (
    flags.bankOrReferenceRequired &&
    fields.bdBankId == null &&
    !fields.instrumentReference.trim()
  ) {
    return 'Select a bank or enter a transaction reference';
  }
  return null;
};

export const paymentInstrumentExtrasValid = (
  flags: ReturnType<typeof paymentMethodFieldFlags>,
  fields: {
    bdBankId: number | null;
    chequeNumber: string;
    instrumentDate: string;
    instrumentReference: string;
  },
) => paymentInstrumentExtrasBlockReason(flags, fields) === null;

export const buildWholesalePaymentInstrument = (input: {
  payment_method_code: string;
  amount: number;
  instrument_reference?: string | null;
  bd_bank_id?: number | null;
  cheque_number?: string | null;
  instrument_date?: string | null;
}): WholesalePaymentInstrumentInput => {
  const ref = input.instrument_reference?.trim() || null;
  const chequeNo = input.cheque_number?.trim() || null;
  const date = input.instrument_date?.trim() || null;
  return {
    payment_method_code: normalizePaymentMethodCode(input.payment_method_code),
    amount: input.amount,
    reference: ref,
    bd_bank_id: input.bd_bank_id ?? null,
    cheque_number: chequeNo,
    cheque_date: date,
  };
};
