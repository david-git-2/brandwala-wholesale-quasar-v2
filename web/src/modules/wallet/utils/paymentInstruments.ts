import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';

export type PaymentInstrumentLineForm = {
  key: string;
  payment_method_code: string;
  amount: number;
  reference: string;
  bd_bank_id: number | null;
  cheque_number: string;
  cheque_date: string;
};

export const localPaymentDate = (): string => {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
};

export const createPaymentInstrumentLine = (): PaymentInstrumentLineForm => ({
  key: crypto.randomUUID(),
  payment_method_code: 'CASH',
  amount: 0,
  reference: '',
  bd_bank_id: null,
  cheque_number: '',
  cheque_date: localPaymentDate(),
});

export const needsPaymentBank = (code: string) => ['CHEQUE', 'BANK_TRANSFER'].includes(code);

export const needsPaymentReference = (code: string) =>
  ['BKASH', 'NAGAD', 'ROCKET', 'UPAY', 'TAP'].includes(code);

export const formatBdtAmount = (value: number): string =>
  `৳${(Number(value) || 0).toLocaleString('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export const paymentMethodFallbackLabel = (code: string): string => {
  const labels: Record<string, string> = {
    CASH: 'Cash',
    CHEQUE: 'Cheque',
    BKASH: 'bKash',
    NAGAD: 'Nagad',
    ROCKET: 'Rocket',
    UPAY: 'Upay',
    TAP: 'Tap',
    BANK_TRANSFER: 'Bank transfer',
  };
  return labels[code] ?? code.replace(/_/g, ' ').toLowerCase();
};

export const mapInstrumentLinesToPayload = (
  lines: PaymentInstrumentLineForm[],
): WholesalePaymentInstrumentInput[] =>
  lines
    .filter((line) => (Number(line.amount) || 0) > 0)
    .map((line) => ({
      payment_method_code: line.payment_method_code,
      amount: Number(line.amount) || 0,
      reference: line.reference.trim() || null,
      bd_bank_id: needsPaymentBank(line.payment_method_code) ? line.bd_bank_id : null,
      cheque_number: line.payment_method_code === 'CHEQUE' ? line.cheque_number.trim() : null,
      cheque_date:
        line.payment_method_code === 'CHEQUE' || line.payment_method_code === 'BANK_TRANSFER'
          ? line.cheque_date || null
          : null,
    }));
