import { ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { useShipmentApFinanceInvalidation } from 'src/modules/procurement_stock/composables/useShipmentApFinance';
import { createPayIdempotencyKey } from '../repositories/paysRepository';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type RecordBillPaymentInput = {
  tenantId: number;
  billId: number;
  isAp: boolean;
  /** Bill debtor (`from_profile_id`) — kernel payer. */
  payerProfileId: number;
  shipmentId?: number | null;
  paidOn: string;
  paymentAmount: number;
  billDueAmount: number;
  settlementCurrencyCode: string;
  /** Cash bundle debited (AP: tenant pot; AR: customer pot after in-memory credit). */
  fromPotId: number;
  /** From bill detail bundle leg — avoids extra balance RPCs. */
  fromPotCurrencyCode?: string;
  fromPotAvailableBalance?: number | null;
  toPotId?: number | null;
  methodCode: string;
  reference: string | null;
  note: string | null;
};

async function resolveFromPotForPay(
  payload: RecordBillPaymentInput,
  allocAmount: number,
  idempotencyKey: string,
): Promise<number> {
  const settle = payload.settlementCurrencyCode.trim().toUpperCase() || 'BDT';
  let fromPotId = payload.fromPotId;

  const potCur =
    (payload.fromPotCurrencyCode ?? settle).trim().toUpperCase() || settle;

  if (potCur !== settle) {
    const provisioned = await moneyKernelRepository.provisionCashbookCurrency(
      payload.tenantId,
      payload.payerProfileId,
      settle,
    );
    const targetPotId = provisioned.pot_id;
    if (targetPotId == null) {
      throw new Error('Could not open a cash bundle in the bill currency.');
    }
    await moneyKernelRepository.transferSameProfile({
      tenantId: payload.tenantId,
      fromPotId,
      toPotId: targetPotId,
      amount: allocAmount,
      idempotencyKey: `${idempotencyKey}-fx`,
    });
    fromPotId = targetPotId;
  }

  return fromPotId;
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
      if (!payload.fromPotId) {
        throw new Error(payload.isAp ? 'Choose which cash point pays this out.' : 'Choose where cash is received.');
      }

      const due = Math.max(0, Number(payload.billDueAmount) || 0);
      const allocAmount = Math.min(payload.paymentAmount, due);
      if (allocAmount <= 0) {
        throw new Error('Payment amount must be greater than zero.');
      }

      const settle = payload.settlementCurrencyCode.trim().toUpperCase() || 'BDT';
      const allocations = [{ bill_id: payload.billId, amount: allocAmount }];

      let fromPotId = payload.fromPotId;

      if (!payload.isAp) {
        const provisioned = await moneyKernelRepository.provisionCashbookCurrency(
          payload.tenantId,
          payload.payerProfileId,
          settle,
        );
        const customerPotId = provisioned.pot_id;
        if (customerPotId == null) {
          throw new Error('Could not open customer cash bundle for this currency.');
        }
        await moneyKernelRepository.deposit({
          tenantId: payload.tenantId,
          profileId: payload.payerProfileId,
          amount: allocAmount,
          currencyCode: settle,
          potId: customerPotId,
          idempotencyKey: `${idempotencyKey}-collect`,
          meta: {
            paid_on: payload.paidOn,
            reference: payload.reference,
            note: payload.note,
          },
        });
        fromPotId = customerPotId;
      }

      fromPotId = await resolveFromPotForPay(
        { ...payload, fromPotId },
        allocAmount,
        idempotencyKey,
      );

      const available =
        payload.fromPotAvailableBalance != null
          ? Number(payload.fromPotAvailableBalance)
          : null;
      if (available != null && available < allocAmount) {
        throw new Error(
          `Not enough balance in this cash bundle (${available} ${settle}, need ${allocAmount}). Add money first.`,
        );
      }

      await moneyKernelRepository.payBills({
        tenantId: payload.tenantId,
        payerProfileId: payload.payerProfileId,
        fromPotId,
        amount: allocAmount,
        allocations,
        toPotId: payload.toPotId ?? undefined,
        meta: {
          paid_on: payload.paidOn,
          method_code: payload.methodCode,
          reference: payload.reference,
          note: payload.note,
          shipment_id: payload.shipmentId ?? null,
        },
        idempotencyKey,
      });

      return { shipmentId: payload.shipmentId ?? null };
    },
    onSettled: () => {
      attemptKey.value = null;
    },
    onSuccess: (result, payload) => {
      const id = billId();
      showSuccessNotification('Payment recorded.');

      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
      }
      if (payload.isAp && result?.shipmentId) {
        invalidateAfterApPay(result.shipmentId);
      }

      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root, refetchType: 'none' });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root, refetchType: 'none' });
      void queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not record payment.');
    },
  });
}
