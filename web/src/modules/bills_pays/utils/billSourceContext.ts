export function formatShopOrderSourceLabel(order: {
  id: number;
  order_no?: string | null;
  name?: string | null;
}): string {
  const label = order.order_no?.trim() || order.name?.trim();
  return label || `Order #${order.id}`;
}

export function formatPbcSourceLabel(file: {
  id: number;
  name?: string | null;
  order_for?: string | null;
}): string {
  const name = file.name?.trim() || file.order_for?.trim();
  if (name) return `${name} (#${file.id})`;
  return `Costing file #${file.id}`;
}
