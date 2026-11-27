export function hasPendingResellDiscount(
  requestedDiscountPrice: number | null | undefined,
): boolean {
  return (
    requestedDiscountPrice != null &&
    !Number.isNaN(requestedDiscountPrice) &&
    requestedDiscountPrice >= 0
  );
}

export function effectiveResellUnitPrice(
  resellPrice: number,
  requestedDiscountPrice: number | null | undefined,
): number {
  if (hasPendingResellDiscount(requestedDiscountPrice)) {
    return requestedDiscountPrice as number;
  }
  return resellPrice;
}