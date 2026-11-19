export const sumBillLineQuantities = (
  lines: ReadonlyArray<{ quantity?: number | string | null }> | undefined,
): number => {
  if (!lines?.length) return 0;
  return lines.reduce((sum, line) => {
    const qty = Number(line.quantity);
    if (!Number.isFinite(qty) || qty <= 0) return sum;
    return sum + qty;
  }, 0);
};

export const formatBillQuantityTotal = (total: number): string => {
  if (!Number.isFinite(total) || total <= 0) return '0';
  const rounded = Math.round(total * 1000) / 1000;
  return Number.isInteger(rounded) ? String(rounded) : String(rounded);
};