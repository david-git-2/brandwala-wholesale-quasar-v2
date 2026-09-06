import { STOREFRONT_WAREHOUSE_GRADES, normalizeStorefrontGradeSlug } from '../constants/storefrontWarehouseGrades';
import type { ShopCatalogStockGrade, ShopStorefrontAdminListing } from '../types';

export interface StorefrontProductGroup {
  product_id: number;
  product_name: string;
  product_brand: string | null;
  product_image_url: string | null;
  listingsByGrade: Record<string, ShopStorefrontAdminListing | null>;
}

const gradeSlugs = () => STOREFRONT_WAREHOUSE_GRADES.map((g) => g.slug);

export function groupStorefrontListingsByProduct(
  listings: ShopStorefrontAdminListing[] | null | undefined,
): StorefrontProductGroup[] {
  if (!Array.isArray(listings) || listings.length === 0) {
    return [];
  }
  const byProduct = new Map<number, StorefrontProductGroup>();

  for (const listing of listings) {
    const slug = normalizeStorefrontGradeSlug(listing.stock_grade?.slug);
    let group = byProduct.get(listing.product_id);
    if (!group) {
      group = {
        product_id: listing.product_id,
        product_name: listing.product_name,
        product_brand: listing.product_brand ?? null,
        product_image_url: listing.product_image_url ?? null,
        listingsByGrade: Object.fromEntries(gradeSlugs().map((s) => [s, null])),
      };
      byProduct.set(listing.product_id, group);
    }
    group.listingsByGrade[slug] = listing;
    if (!group.product_image_url && listing.product_image_url) {
      group.product_image_url = listing.product_image_url;
    }
  }

  return [...byProduct.values()].sort((a, b) => a.product_name.localeCompare(b.product_name));
}

export function pickDefaultGradeSlug(group: StorefrontProductGroup): string {
  const byGrade = group?.listingsByGrade;
  if (!byGrade) return 'standard';
  for (const slug of gradeSlugs()) {
    if (byGrade[slug] != null) return slug;
  }
  const extra = Object.entries(byGrade).find(([, listing]) => listing != null);
  return extra?.[0] ?? 'standard';
}

export function gradeListingState(
  listing: ShopStorefrontAdminListing | null | undefined,
): 'unlisted' | 'active' | 'inactive' {
  if (!listing) return 'unlisted';
  return listing.listing_status === 'inactive' ? 'inactive' : 'active';
}

export function findSiblingListingForPricing(
  group: StorefrontProductGroup,
): ShopStorefrontAdminListing | null {
  for (const slug of gradeSlugs()) {
    const row = group.listingsByGrade[slug];
    if (row) return row;
  }
  return null;
}

export type { ShopCatalogStockGrade };
