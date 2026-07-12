export interface PurchaseBalanceItemInput {
  id: number;
  name: string;
  purchase_price: number; // in purchase currency
  ordered_quantity: number;
}

export interface PurchaseAdjustmentResult {
  itemId: number;
  newPurchasePrice: number; // in purchase currency, rounded to 4 decimal places
  perUnitDelta: number;
}

/**
 * Calculates estimated purchase total from line items.
 */
export function calculateEstimatedPurchaseTotal(items: PurchaseBalanceItemInput[]): number {
  return items.reduce((sum, item) => sum + (item.purchase_price || 0) * (item.ordered_quantity || 0), 0);
}

/**
 * Computes proportional purchase price adjustments to distribute the estimated-vs-actual purchase total delta.
 */
export function computePurchasePriceAdjustments(
  items: PurchaseBalanceItemInput[],
  actualTotal: number,
): PurchaseAdjustmentResult[] {
  if (items.length === 0) {
    throw new Error('At least one shipment line item is required to perform purchase balance.');
  }

  const hasPositiveQtyItem = items.some((item) => (item.ordered_quantity || 0) > 0);
  if (!hasPositiveQtyItem) {
    throw new Error('At least one shipment line must have an ordered quantity greater than 0.');
  }

  const estimatedTotal = calculateEstimatedPurchaseTotal(items);
  const delta = actualTotal - estimatedTotal;

  if (estimatedTotal === 0) {
    if (delta !== 0) {
      throw new Error(
        'Estimated purchase total is 0. Cannot proportionally adjust prices. Please set manual base prices on your line items first so they have a distribution basis.'
      );
    }
    // If both are 0, no adjustments needed
    return items.map((item) => ({
      itemId: item.id,
      newPurchasePrice: item.purchase_price,
      perUnitDelta: 0,
    }));
  }

  const adjustmentsMap = new Map<
    number,
    {
      newPriceRaw: number;
      newPriceRounded: number;
      grossValue: number;
      qty: number;
      originalPrice: number;
    }
  >();

  let sumAdjusted = 0;
  let maxValue = -1;
  let maxValueItemId = -1;

  for (const item of items) {
    const qty = item.ordered_quantity || 0;
    const currentGross = (item.purchase_price || 0) * qty;

    if (currentGross > maxValue) {
      maxValue = currentGross;
      maxValueItemId = item.id;
    }

    if (qty === 0) {
      adjustmentsMap.set(item.id, {
        newPriceRaw: item.purchase_price,
        newPriceRounded: item.purchase_price,
        grossValue: 0,
        qty: 0,
        originalPrice: item.purchase_price,
      });
      continue;
    }

    const share = currentGross / estimatedTotal;
    const lineDelta = delta * share;
    const perUnitDelta = lineDelta / qty;
    const newPriceRaw = item.purchase_price + perUnitDelta;

    if (newPriceRaw < 0) {
      throw new Error(
        `Purchase price for line "${item.name}" would go below 0 after adjustment (${newPriceRaw.toFixed(6)}). Adjustments blocked.`
      );
    }

    const newPriceRounded = Math.round(newPriceRaw * 1000000) / 1000000;
    sumAdjusted += newPriceRounded * qty;

    adjustmentsMap.set(item.id, {
      newPriceRaw,
      newPriceRounded,
      grossValue: currentGross,
      qty,
      originalPrice: item.purchase_price,
    });
  }

  // Handle rounding remainder
  const remainder = actualTotal - sumAdjusted;
  if (Math.abs(remainder) > 0.000001 && maxValueItemId !== -1) {
    const target = adjustmentsMap.get(maxValueItemId);
    if (target && target.qty > 0) {
      const additionalPerUnit = remainder / target.qty;
      const adjustedPriceRaw = target.newPriceRounded + additionalPerUnit;

      if (adjustedPriceRaw < 0) {
        throw new Error(
          `Purchase price for line "${items.find((i) => i.id === maxValueItemId)?.name}" would go below 0 after remainder distribution (${adjustedPriceRaw.toFixed(6)}). Adjustments blocked.`
        );
      }

      target.newPriceRounded = Math.round(adjustedPriceRaw * 1000000) / 1000000;
      adjustmentsMap.set(maxValueItemId, target);
    }
  }

  return items.map((item) => {
    const data = adjustmentsMap.get(item.id)!;
    return {
      itemId: item.id,
      newPurchasePrice: data.newPriceRounded,
      perUnitDelta: data.newPriceRounded - data.originalPrice,
    };
  });
}
