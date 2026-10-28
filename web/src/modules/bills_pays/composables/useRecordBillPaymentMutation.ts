import { ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  postApPayoutSnapshot,
  type ApPayoutBillDetailSnapshot,
} from '../services/apPayoutService';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { useShipmentApFinanceInvalidation } from 'src/modules/procurement_stock/composables/useShipmentApFinance';
import { createPayIdempotencyKey, paysRepository } from '../repositories/paysRepository';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { buildWholesalePaymentInstrument } from '../utils/paymentInstrumentFields';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import type { BillDetailBundle } from '../repositories/billsRepository';
import type { BillNetBalances } from '../types/billBalances';

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

function applyApPayoutSnapshotToCache(
  queryClient: ReturnType<typeof useQueryClient>,
  billId: number,
  snapshot: ApPayoutBillDetailSnapshot,
) {
  queryClient.setQueryData<BillDetailBundle | undefined>(
    billsQueryKeys.detailBundle(billId),
    (old) => {
      if (!old) return old;
      return {
        ...old,
        bill: snapshot.bill
          ? ({ ...old.bill, ...snapshot.bill } as GlobalInvoiceDetail)
          : old.bill,
        netBalances: snapshot.net_balances
          ? (snapshot.net_balances as BillNetBalances)
          : old.netBalances,
        paymentHistory:
          snapshot.payment_history != null
            ? (snapshot.payment_history as InvoicePaymentHistoryEntry[])
            : old.paymentHistory,
      };
    },
  );
}

export function useRecordBillPaymentMutation(billId: () => number | null) {
  const queryClient = useQueryClient();
  const { invalidateAfterApPay } = useShipmentApFinanceInvalidation();
  const attemptKey = ref<string | null>(null);

  return useMutation({
    onMutate: () => {
      if (!attemptKey.value) {
        attemptKey.value = createPayIdempotencyKey();
      }
    },
    mutationFn: async (payload: RecordBillPaymentInput) => {
      const idempotencyKey = attemptKey.value ?? createPayIdempotencyKey();
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
          cashbook_point_id: payload.cashbookPointId ?? null,
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
        const apPayload = {
          tenant_id: payload.tenantId,
          profile_id: payload.profileId,
          cashbook_point_id: payload.cashbookPointId,
          paid_on: payload.paidOn,
          note: payload.note,
          reference: payload.reference,
          instruments,
          allocations,
          amount: payload.amountBdt,
          settlement_currency_code: fx.settlement_currency_code,
          foreign_amount: fx.foreign_amount,
          exchange_rate: fx.exchange_rate,
          source_currency_code: payload.sourceCurrencyCode ?? undefined,
          transaction_rate: payload.transactionRate ?? undefined,
          cashbook_point_pot_id: payload.cashbookPointPotId ?? undefined,
          shipment_id: null as number | null,
          idempotency_key: idempotencyKey,
        };
        const snapshotResult = await postApPayoutSnapshot(apPayload);
        return snapshotResult;
      }

      if (!payload.isAp && !payload.cashbookPointId) {
        throw new Error('Choose where to receive cash.');
      }

      await paysRepository.postMoneyIn({
        tenant_id: payload.tenantId,
        profile_id: payload.profileId,
        received_on: payload.paidOn,
        note: payload.note,
        reference: payload.reference,
        source: hasBank ? 'bank' : 'customer_cash',
        instruments,
        allocations,
        ...fx,
        idempotency_key: idempotencyKey,
        cashbook_point_id: payload.cashbookPointId ?? null,
        cashbook_point_pot_id: payload.cashbookPointPotId ?? null,
        source_currency_code: payload.sourceCurrencyCode ?? null,
        transaction_rate: payload.transactionRate ?? null,
      });
      return null;
    },
    onSettled: () => {
      attemptKey.value = null;
    },
    onSuccess: (snapshot, payload) => {
      const id = billId();
      showSuccessNotification('Payment recorded.');

      if (payload.isAp && snapshot && id) {
        applyApPayoutSnapshotToCache(queryClient, id, snapshot);
        for (const sid of snapshot.shipmentIds ?? []) {
          invalidateAfterApPay(sid);
        }
      } else if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
      }

      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root, refetchType: 'none' });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root, refetchType: 'none' });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not record payment.');
    },
  });
}
