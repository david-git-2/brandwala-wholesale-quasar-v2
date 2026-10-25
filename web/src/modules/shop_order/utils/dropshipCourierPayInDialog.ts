import { Dialog } from 'quasar';
import DropshipCourierPayInDialog from '../components/DropshipCourierPayInDialog.vue';
import type { FinanceHubOrderQueueItem } from '../repositories/dropshipFinanceRepository';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';

export type DropshipCourierPayInSubmitPayload = {
  orderId: number;
  netAmount: number;
  courierCharge: number;
  deliveryCharge: number;
  codCharge: number;
  remittanceRef?: string;
  bankTrxId?: string;
  cashbookPointId: number;
};

function chargeLineAmount(
  view: DropshipManagementOrderView,
  chargeType: 'delivery' | 'cod',
): number {
  const line = view.settlement.charge_lines.find((c) => c.charge_type === chargeType);
  return line ? Number(line.amount) || 0 : 0;
}

export function toFinanceHubQueueItemFromManagementView(
  view: DropshipManagementOrderView,
): FinanceHubOrderQueueItem {
  const codCollect =
    Number(view.settlement.collected_cod_amount) ||
    Number(view.courier.cod_collect_amount) ||
    0;
  const deliveryCharge = chargeLineAmount(view, 'delivery');
  const codCharge =
    Number(view.order.cod_charge_amount) || chargeLineAmount(view, 'cod');

  return {
    id: view.order.id,
    orderNo: view.order.order_no,
    customerName: view.order.recipient_name,
    shopName: view.order.customer_group_name,
    courierName: view.order.courier_name ?? view.courier.courier_name,
    status: view.order.status,
    totalAmount: view.invoice?.total_amount ?? 0,
    codCollectAmount: codCollect,
    deliveryChargeAmount: deliveryCharge,
    codChargeAmount: codCharge,
    courierNotes: null,
    courierRemittanceRef: null,
    courierBankTrxId: null,
    profileId: null,
    customerProfileName: view.order.customer_group_name,
    createdAt: view.order.created_at,
    nextStep: 'courier_remittance',
    invoiceOutstanding: view.invoice?.due_amount ?? null,
  };
}

export function requestDropshipCourierPayInDialog(
  selectedOrder: FinanceHubOrderQueueItem,
  options?: { loading?: boolean },
): Promise<DropshipCourierPayInSubmitPayload | null> {
  return new Promise((resolve) => {
    Dialog.create({
      component: DropshipCourierPayInDialog,
      componentProps: {
        selectedOrder,
        loading: options?.loading ?? false,
      },
    })
      .onOk((payload: DropshipCourierPayInSubmitPayload) => resolve(payload))
      .onCancel(() => resolve(null))
      .onDismiss(() => resolve(null));
  });
}
