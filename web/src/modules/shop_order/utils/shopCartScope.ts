import type { ActiveCartItem } from '../repositories/shopCartRepository';

export type ShopCartKindFilter = 'catalog' | 'dropship' | 'all';

export function filterActiveCartsByKind(
  carts: ActiveCartItem[],
  kind: ShopCartKindFilter = 'all',
): ActiveCartItem[] {
  if (kind === 'dropship') {
    return carts.filter((cart) => cart.shop_type === 'dropship');
  }
  if (kind === 'catalog') {
    return carts.filter((cart) => cart.shop_type !== 'dropship');
  }
  return carts;
}
