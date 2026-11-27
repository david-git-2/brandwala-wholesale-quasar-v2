import type { ShopType } from '../types';

export const SHOP_TYPE_PATH_SEGMENTS = ['catalog', 'stock', 'dropship'] as const;
export type ShopTypePathSegment = (typeof SHOP_TYPE_PATH_SEGMENTS)[number];

const PATH_TO_ENUM: Record<ShopTypePathSegment, ShopType> = {
  catalog: 'vendor_catalog',
  stock: 'fixed_price',
  dropship: 'dropship',
};

const ENUM_TO_PATH: Record<ShopType, ShopTypePathSegment> = {
  vendor_catalog: 'catalog',
  fixed_price: 'stock',
  dropship: 'dropship',
};

export function shopTypeFromPathSegment(segment: string | null | undefined): ShopType | null {
  if (!segment) return null;
  const key = segment.trim().toLowerCase() as ShopTypePathSegment;
  return PATH_TO_ENUM[key] ?? null;
}

export function shopTypeToPathSegment(shopType: ShopType | null | undefined): ShopTypePathSegment | null {
  if (!shopType) return null;
  return ENUM_TO_PATH[shopType] ?? null;
}

export function isShopTypePathSegment(value: string): value is ShopTypePathSegment {
  return SHOP_TYPE_PATH_SEGMENTS.includes(value as ShopTypePathSegment);
}