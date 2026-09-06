import type { ShopCatalogStockGrade } from '../types';

export const STOREFRONT_WAREHOUSE_GRADES: ShopCatalogStockGrade[] = [
  { slug: 'standard', label: 'Standard', color: '#22c55e' },
  { slug: 'open_box', label: 'Open box', color: '#3b82f6' },
  { slug: 'box_damage', label: 'Box damage', color: '#f59e0b' },
  { slug: 'box_less', label: 'Box less', color: '#8b5cf6' },
];

export const normalizeStorefrontGradeSlug = (slug: string | null | undefined): string =>
  slug?.trim() || 'standard';
