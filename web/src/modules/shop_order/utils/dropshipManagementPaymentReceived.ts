import type { ShopOrder } from '../types';
import { expectedCourierRemittanceNet } from './expectedCourierRemittanceNet';

export type DropshipMgmtPaymentReceivedMoney = {
  orderId: number;
  orderNo: string;
  collectedCod: number;
  delivery: number;
  codRate: number;
  courierPaysTenant: number;
  customerArPaid: number;
  dropshipperProfit: number;
  remittanceRef: string;
  remittanceNote: string;
};

export function buildDropshipMgmtPaymentReceivedMoney(
  order: ShopOrder,
  overrides?: { collectedCod?: number; delivery?: number; codRate?: number },
): DropshipMgmtPaymentReceivedMoney {
  const collectedCod =
    overrides?.collectedCod ??
    Number(order.collected_cod_amount ?? order.cod_collect_amount ?? 0);
  const delivery =
    overrides?.delivery ?? Number(order.delivery_charge_amount ?? 0);
  const codRate = overrides?.codRate ?? Number(order.cod_charge_amount ?? 0);
  const courierPaysTenant = expectedCourierRemittanceNet({
    codCollectAmount: collectedCod,
    deliveryChargeAmount: delivery,
    codChargeAmount: codRate,
  });
  const customerArPaid = Math.max(0, Number(order.dropshipper_bill_amount ?? 0));
  const dropshipperProfit = Math.max(0, courierPaysTenant - customerArPaid);
  const orderNo = order.order_no || String(order.id);

  return {
    orderId: order.id,
    orderNo,
    collectedCod,
    delivery,
    codRate,
    courierPaysTenant,
    customerArPaid,
    dropshipperProfit,
    remittanceRef: `REMIT-${order.id}`,
    remittanceNote: `Courier remittance order #${orderNo}`,
  };
}