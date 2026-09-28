/** True when courier bank-in is expected (recipient COD), not merchant prepaid. */
export function isDropshipRecipientCodRemittancePending(order: {
  courierRemittanceRef?: string | null;
  codCollectAmount?: number | null;
  isPrepaidSnapshot?: boolean | null;
}): boolean {
  if (order.courierRemittanceRef) return false;
  if ((Number(order.codCollectAmount) || 0) <= 0) return false;
  if (order.isPrepaidSnapshot) return false;
  return true;
}
