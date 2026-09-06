import type { ShopCatalogStockGrade, ShopStorefrontAdminListing } from '../types';
import { normalizeStorefrontGradeSlug } from '../constants/storefrontWarehouseGrades';
import { gradeListingState } from './storefrontProductGroups';

export const gradeShortLabel = (grade: ShopCatalogStockGrade) => {
  const map: Record<string, string> = {
    standard: 'Std',
    open_box: 'Open',
    box_damage: 'Dmg',
    box_less: 'NoBx',
  };
  return map[grade.slug] ?? grade.label;
};

export const gradeAccentColor = (grade: ShopCatalogStockGrade) => grade.color?.trim() || '#6b7280';

export const hexToRgba = (hex: string, alpha: number) => {
  const normalized = hex.replace('#', '');
  if (normalized.length !== 6) return `rgba(107, 114, 128, ${alpha})`;
  const r = Number.parseInt(normalized.slice(0, 2), 16);
  const g = Number.parseInt(normalized.slice(2, 4), 16);
  const b = Number.parseInt(normalized.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

export const gradeListingStateForSlug = (
  listingsByGrade: Record<string, ShopStorefrontAdminListing | null>,
  slug: string,
) => gradeListingState(listingsByGrade[normalizeStorefrontGradeSlug(slug)]);

export const gradeButtonStyle = (
  grade: ShopCatalogStockGrade,
  selected: boolean,
  state: 'unlisted' | 'active' | 'inactive',
) => {
  const color = gradeAccentColor(grade);

  if (selected) {
    return {
      backgroundColor: color,
      borderColor: color,
      color: '#ffffff',
    };
  }

  if (state === 'unlisted') {
    return {
      backgroundColor: 'transparent',
      borderColor: hexToRgba(color, 0.22),
      color: hexToRgba(color, 0.72),
    };
  }

  if (state === 'inactive') {
    return {
      backgroundColor: hexToRgba(color, 0.08),
      borderColor: hexToRgba(color, 0.3),
      color: hexToRgba(color, 0.85),
    };
  }

  return {
    backgroundColor: hexToRgba(color, 0.16),
    borderColor: hexToRgba(color, 0.42),
    color,
  };
};
