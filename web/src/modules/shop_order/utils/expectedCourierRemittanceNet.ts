/** Net bank in expected from courier after delivery + COD fees (order snapshot). */
export function expectedCourierRemittanceNet(order: {
  codCollectAmount?: number | null;
  deliveryChargeAmount?: number | null;
  codChargeAmount?: number | null;
}): number {
  const cod = Number(order.codCollectAmount) || 0;
  const fees =
    (Number(order.deliveryChargeAmount) || 0) + (Number(order.codChargeAmount) || 0);
  return Math.max(0, cod - fees);
}
