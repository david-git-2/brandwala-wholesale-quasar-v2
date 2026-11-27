import type { ShopTypePathSegment } from './shopRouteTypes';
import { shopTypeFromPathSegment } from './shopRouteTypes';
import type { ActiveCartItem } from '../repositories/shopCartRepository';

export type ShopCartKindFilter = 'catalog' | 'dropship' | 'all' | ShopTypePathSegment;

export function filterActiveCartsByKind(
  carts: ActiveCartItem[],
  kind: ShopCartKindFilter = 'all',
): ActiveCartItem[] {
  if (kind === 'all') {
    return carts;
  }
  if (kind === 'dropship') {
    return carts.filter((cart) => cart.shop_type === 'dropship');
  }
  if (kind === 'catalog') {
    return carts.filter((cart) => cart.shop_type === 'vendor_catalog');
  }
  if (kind === 'stock') {
    return carts.filter((cart) => cart.shop_type === 'fixed_price');
  }
  const shopType = shopTypeFromPathSegment(kind);
  if (!shopType) {
    return carts;
  }
  return carts.filter((cart) => cart.shop_type === shopType);
}

export function filterActiveCartsByShopTypePath(
  carts: ActiveCartItem[],
  shopTypePath: ShopTypePathSegment,
): ActiveCartItem[] {
  return filterActiveCartsByKind(carts, shopTypePath);
}
