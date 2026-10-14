import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { buildWholesalePaymentInstrument } from '../utils/paymentInstrumentFields';

type InstrumentFieldValues = {
  bdBankId: number | null;
  chequeNumber: string;
  instrumentDate: string;
  instrumentReference: string;
};

export type RecordBillPaymentInput = {
  tenantId: number;
  billId: number;
  isAp: boolean;
  profileId: number;
  cashbookPointId?: number | null;
  paidOn: string;
  amountBdt: number;
  /** Bill due at submit time; allocation is capped here when payment is higher. */
  billDueAmount: number;
  settlementCurrencyCode: string;
  /** Parent books currency; FX omitted when settlement matches this. */
  booksCurrencyCode?: string;
  foreignAmount: number | null;
  exchangeRate: number | null;
  sourceCurrencyCode?: string | null;
  transactionRate?: number | null;
  cashbookPointPotId?: number | null;
  methodCode: string;
  reference: string | null;
  note: string | null;
  instrumentFields: InstrumentFieldValues;
};

export function useRecordBillPaymentMutation(billId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: RecordBillPaymentInput) => {
      const hasBank = ['bank_transfer', 'bank', 'cheque'].includes(
        payload.methodCode.toLowerCase(),
      );
      const instruments = [
        buildWholesalePaymentInstrument({
          payment_method_code: payload.methodCode,
          amount: payload.amountBdt,
          instrument_reference: payload.instrumentFields.instrumentReference,
          bd_bank_id: payload.instrumentFields.bdBankId,
          cheque_number: payload.instrumentFields.chequeNumber,
          instrument_date: payload.instrumentFields.instrumentDate,
          cashbook_point_id: payload.isAp ? payload.cashbookPointId ?? null : null,
        }),
      ];
      const due = Math.max(0, Number(payload.billDueAmount) || 0);
      const allocAmount = Math.min(payload.amountBdt, due);
      const allocations =
        allocAmount > 0 ? [{ bill_id: payload.billId, amount: allocAmount }] : [];
      const booksBase = (payload.booksCurrencyCode ?? 'BDT').trim().toUpperCase();
      const settle = (payload.settlementCurrencyCode ?? booksBase).trim().toUpperCase();
      const needsBooksFx = settle !== booksBase;
      const fx = {
        settlement_currency_code: payload.settlementCurrencyCode,
        foreign_amount: needsBooksFx ? payload.foreignAmount : null,
        exchange_rate: needsBooksFx ? payload.exchangeRate : null,
      };

      if (payload.isAp) {
        if (!payload.cashbookPointId) {
          throw new Error('Choose which cash point pays this out.');
        }
        await paysRepository.postApPayoutWithAllocations({
          tenant_id: payload.tenantId,
          profile_id: payload.profileId,
          cashbook_point_id: payload.cashbookPointId,
          paid_on: payload.paidOn,
          note: payload.note,
          reference: payload.reference,
          instruments,
          allocations,
          settlement_currency_code: fx.settlement_currency_code,
          foreign_amount: fx.foreign_amount,
          exchange_rate: fx.exchange_rate,
          source_currency_code: payload.sourceCurrencyCode ?? null,
          transaction_rate: payload.transactionRate ?? null,
          cashbook_point_pot_id: payload.cashbookPointPotId ?? null,
        });
      } else {
        await paysRepository.postCustomerReceipt({
          tenant_id: payload.tenantId,
          profile_id: payload.profileId,
          received_on: payload.paidOn,
          note: payload.note,
          reference: payload.reference,
          source: hasBank ? 'bank' : 'customer_cash',
          instruments,
          allocations,
          ...fx,
        });
      }
    },
    onSuccess: () => {
      const id = billId();
      showSuccessNotification('Payment recorded.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
        void queryClient.invalidateQueries({
          queryKey: [...billsQueryKeys.detail(id), 'net-balances'],
        });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.paymentHistory(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.adjustments(id) });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not record payment.');
    },
  });
}
