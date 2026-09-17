/**
 * Products & Tag Catalog Stubs & Mock Data Provider
 * Used for isolated product catalog testing and taxonomy verification.
 */

export interface ProductStub {
  id: string;
  name: string;
  product_code: string;
  barcode: string;
  brand_name: string;
  category_name: string;
  list_price_amount: number;
  list_price_currency: string;
  unit_weight_kg: number;
  image_url?: string;
  is_active: boolean;
}

export const mockProducts: ProductStub[] = [
  {
    id: 'prod-stub-001',
    name: 'Cotton Pique Polo Shirt (CP-4)',
    product_code: 'BW-CP4-NVY',
    barcode: '8901234567890',
    brand_name: 'Brandwala Essentials',
    category_name: 'Apparel > Men',
    list_price_amount: 4.5,
    list_price_currency: 'GBP',
    unit_weight_kg: 0.25,
    is_active: true,
  },
  {
    id: 'prod-stub-002',
    name: 'MA-1 Bomber Flight Jacket',
    product_code: 'ALPH-JKT-002',
    barcode: '8901234567891',
    brand_name: 'Alpha Wear',
    category_name: 'Outerwear',
    list_price_amount: 18.0,
    list_price_currency: 'GBP',
    unit_weight_kg: 0.85,
    is_active: true,
  },
  {
    id: 'prod-stub-003',
    name: 'Full Grain Leather Bifold Wallet',
    product_code: 'HRTG-WAL-003',
    barcode: '8901234567892',
    brand_name: 'Heritage BD',
    category_name: 'Accessories',
    list_price_amount: 8.0,
    list_price_currency: 'GBP',
    unit_weight_kg: 0.15,
    is_active: true,
  },
];

export async function fetchMockProducts(): Promise<ProductStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockProducts];
}
