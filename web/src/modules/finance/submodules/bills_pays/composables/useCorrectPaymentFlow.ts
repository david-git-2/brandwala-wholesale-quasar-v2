import { ref, type Ref, type ComputedRef } from 'vue';
import { useQueryClient } from '@tanstack/vue-query';
import { paysRepository, type PayDetail } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { buildPayCorrectionSnapshot } from '../utils/buildPayCorrectionSnapshot';
import { isPayVoidable } from '../utils/payVoidability';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useCorrectPaymentFlow(options?: {
  billId?: Ref<number | null> | ComputedRef<number | null>;
  onVoided?: (snapshot: PayCorrectionSnapshot) => void | Promise<void>;
}) {
  const queryClient = useQueryClient();
  const dialogOpen = ref(false);
  const voiding = ref(false);
  const displayPay = ref<PayDetail | null>(null);
  const pendingPaymentId = ref<number | null>(null);

  const openCorrect = async (paymentId: number) => {
    try {
      const pay = await paysRepository.getPayById(paymentId);
      if (
        !isPayVoidable({
          source: pay.source,
          method: pay.method,
          voidedAt: pay.voided_at,
        })
      ) {
        showErrorNotification('This payment cannot be corrected here.');
        return;
      }
      pendingPaymentId.value = paymentId;
      displayPay.value = pay;
      dialogOpen.value = true;
    } catch (e) {
      showErrorNotification(e instanceof Error ? e.message : 'Could not load payment.');
    }
  };

  const closeDialog = () => {
    dialogOpen.value = false;
    displayPay.value = null;
    pendingPaymentId.value = null;
  };

  const confirmVoid = async (reason: string) => {
    const paymentId = pendingPaymentId.value;
    const pay = displayPay.value;
    if (!paymentId || !pay) return;

    const trimmed = reason.trim();
    if (!trimmed) {
      showErrorNotification('Enter a reason.');
      return;
    }

    const snapshot = buildPayCorrectionSnapshot(pay);
    voiding.value = true;
    try {
      await paysRepository.reversePay(paymentId, trimmed);
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root, refetchType: 'none' });
      void queryClient.invalidateQueries({
        queryKey: paysQueryKeys.detail(paymentId),
        refetchType: 'none',
      });
      closeDialog();
      showSuccessNotification('Payment voided. Enter the correct payment.');
      await options?.onVoided?.(snapshot);
    } catch (e) {
      showErrorNotification(e instanceof Error ? e.message : 'Could not void payment.');
    } finally {
      voiding.value = false;
    }
  };

  return {
    dialogOpen,
    voiding,
    displayPay,
    openCorrect,
    closeDialog,
    confirmVoid,
  };
}
